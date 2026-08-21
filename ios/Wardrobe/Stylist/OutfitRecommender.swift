import Foundation
import Observation
import SwiftData

/// Normalizes the optional user context to the backend's 128-code-point limit
/// without cutting a composed character in half.
enum StylingOccasion {
    static let maximumLength = 128

    static func limited(_ value: String) -> String {
        var scalarCount = 0
        let prefix = value.prefix { character in
            let nextCount = scalarCount + character.unicodeScalars.count
            guard nextCount <= maximumLength else { return false }
            scalarCount = nextCount
            return true
        }
        return String(prefix)
    }

    static func requestValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = limited(trimmed)
        return result.isEmpty ? nil : result
    }
}

/// Orchestrates the daily recommendation flow (Phase 5, "Aria"):
///
///   SwiftData `Item`s + recent `WearLog`s
///       → CatalogCompactor + WearHistory (compact, on-device)
///       → RecommendClient `/recommend` (Claude Opus 4.8)
///       → resolve returned ids back to `Item`s → a renderable look + alternates
///
/// "Wear this" persists an `Outfit` plus a per-item `WearLog`, which feeds the
/// next day's anti-repeat. Stateful only for UI observation; all SwiftData reads
/// happen up front (before any `await`) to stay in one main-actor slice.
@MainActor
@Observable
final class OutfitRecommender {

    struct WardrobeSnapshot {
        let items: [Item]
        let outfits: [Outfit]
        let wears: [WearLog]
    }

    typealias SnapshotLoader = @MainActor () throws -> WardrobeSnapshot

    /// One renderable look — the primary or an alternate.
    struct Look: Identifiable {
        let id = UUID()
        let items: [Item]
        let rationale: String
    }

    /// A full recommendation: the primary look first, then alternates, with a
    /// cursor so "show me another" can cycle without a new backend call.
    struct Recommendation {
        let occasion: String
        let colorStory: String
        let looks: [Look]
        let generatedAt: Date
        let isCached: Bool
        var wornItemIDSetsToday: Set<Set<UUID>>
        /// Transient UI feedback only; `DailyLookCacheEntry` never persists it.
        var refreshFailureMessage: String? = nil
        var index: Int = 0

        var current: Look { looks[index] }
        var hasAlternates: Bool { looks.count > 1 }
        var wasWornToday: Bool {
            wornItemIDSetsToday.contains(Set(current.items.map(\.id)))
        }

        mutating func markCurrentWorn() {
            wornItemIDSetsToday.insert(Set(current.items.map(\.id)))
        }
    }

    enum State {
        case idle
        case loading
        case loaded(Recommendation)
        case emptyCatalog
        case consentRequired(PrivacyGateDenial)
        case failed(message: String)
    }

    var state: State = .idle
    private(set) var isRequestInFlight = false

    private let recommendClient: RecommendClient
    private let modelContext: ModelContext
    private let store: any WardrobeStoring
    private let now: () -> Date
    private let privacyGate: any PrivacyGateChecking
    private let privacySubjectID: PrivacySubjectID
    private let accountScope: WardrobeAccountScope
    private let dailyLookCache: any DailyLookCaching
    private let calendar: Calendar
    private let loadSnapshot: SnapshotLoader

    /// An outfit needs at least this many items to be worth recommending.
    private static let minimumCatalogItems = RecommendContractLimits.minimumItems

    init(
        recommendClient: RecommendClient,
        modelContext: ModelContext,
        store: (any WardrobeStoring)? = nil,
        privacyGate: any PrivacyGateChecking = StoredPrivacyGatekeeper(),
        privacySubjectID: PrivacySubjectID = .deviceLocal,
        accountScope: WardrobeAccountScope = .deviceLocal,
        dailyLookCache: any DailyLookCaching = DisabledDailyLookCache(),
        calendar: Calendar = .autoupdatingCurrent,
        loadSnapshot: SnapshotLoader? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.recommendClient = recommendClient
        self.modelContext = modelContext
        self.store = store ?? WardrobeStore(
            modelContext: modelContext,
            accountScope: accountScope
        )
        self.privacyGate = privacyGate
        self.privacySubjectID = privacySubjectID
        self.accountScope = accountScope
        self.dailyLookCache = dailyLookCache
        self.calendar = calendar
        self.loadSnapshot = loadSnapshot ?? {
            WardrobeSnapshot(
                items: try modelContext.fetch(FetchDescriptor<Item>()),
                outfits: try modelContext.fetch(FetchDescriptor<Outfit>()),
                wears: try modelContext.fetch(FetchDescriptor<WearLog>())
            )
        }
        self.now = now
    }

    /// Load today's compatible cached look or fetch a fresh recommendation from
    /// Aria. An empty occasion can restore the one look saved for this account;
    /// a non-empty occasion always requires an exact normalized match.
    func recommend(occasion: String? = nil, refresh: Bool = false) async {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true
        defer { isRequestInFlight = false }
        let requestOccasion = StylingOccasion.requestValue(occasion)

        let privacyDecision = await privacyGate.decision(
            for: .aiStyling,
            subjectID: privacySubjectID
        )
        guard !Task.isCancelled else { return }
        guard privacyDecision.isAllowed else {
            if case .denied(let denial) = privacyDecision {
                state = .consentRequired(denial)
            }
            return
        }
        let stateBeforeRequest = state

        // 1. Snapshot the catalog + wear history up front, before any await.
        let items: [Item]
        let outfits: [Outfit]
        let recentlyWornIDs: [String]
        let itemPreferences: [RecommendItemPreference]
        let compactCatalog: [RecommendCatalogItem]
        do {
            let snapshot = try loadSnapshot()
            items = WardrobeAccountFilter.styleableItems(
                from: snapshot.items,
                in: accountScope
            )
            outfits = WardrobeAccountFilter.visibleOutfits(
                from: snapshot.outfits,
                in: accountScope
            )
            let wears = WardrobeAccountFilter.visibleWearLogs(
                from: snapshot.wears,
                in: accountScope
            )
            compactCatalog = CatalogCompactor.compact(items)
            let activeItemIDs = Set(compactCatalog.map(\.id))
            recentlyWornIDs = WearHistory.recentlyWornIDs(
                from: wears, since: WearHistory.cutoff(from: now())
            ).filter(activeItemIDs.contains)
            itemPreferences = WearHistory.itemPreferences(from: wears).filter {
                activeItemIDs.contains($0.id)
            }
        } catch {
            guard !Task.isCancelled else { return }
            let message = "We couldn’t open your wardrobe for styling. Your items are still on this device. Please try again."
            state = Self.retainingLoadedRecommendation(
                from: stateBeforeRequest,
                afterRefreshFailure: message,
                refresh: refresh
            ) ?? .failed(message: message)
            return
        }

        guard !Task.isCancelled else { return }
        guard items.count >= Self.minimumCatalogItems else {
            state = .emptyCatalog
            return
        }

        let requestDate = now()
        let fingerprint = DailyLookCatalogFingerprint.make(from: compactCatalog)
        if !refresh,
           let cached = dailyLookCache.load(for: accountScope),
           cached.isReusable(
               at: requestDate,
               calendar: calendar,
               catalogFingerprint: fingerprint,
               occasion: requestOccasion,
               acceptsStoredOccasionWhenRequestIsEmpty: true
           ) {
            let cachedState = resolve(
                cached.response,
                catalog: items,
                generatedAt: cached.generatedAt,
                isCached: true,
                wornItemIDSetsToday: wornItemIDSetsToday(among: outfits, at: requestDate)
            )
            guard !Task.isCancelled else { return }
            if case .loaded = cachedState {
                state = cachedState
                return
            }
            guard !Task.isCancelled else { return }
            dailyLookCache.remove(for: accountScope)
        }

        guard !Task.isCancelled else { return }
        let stateBeforeLoading = stateBeforeRequest
        state = .loading
        let request = RecommendRequest(
            items: compactCatalog,
            recentlyWornIds: recentlyWornIDs,
            itemPreferences: itemPreferences,
            occasion: requestOccasion
        )

        do {
            try Task.checkCancellation()
            let response = try await recommendClient.recommend(request)
            try Task.checkCancellation()
            let completedAt = now()
            let resolved = resolve(
                response,
                catalog: items,
                generatedAt: completedAt,
                isCached: false,
                wornItemIDSetsToday: wornItemIDSetsToday(among: outfits, at: completedAt)
            )
            try Task.checkCancellation()
            if case .failed(let message) = resolved,
               let retained = Self.retainingLoadedRecommendation(
                   from: stateBeforeLoading,
                   afterRefreshFailure: message,
                   refresh: refresh
               ) {
                state = retained
            } else {
                state = resolved
            }
            if case .loaded = resolved {
                try Task.checkCancellation()
                dailyLookCache.save(
                    DailyLookCacheEntry(
                        generatedAt: completedAt,
                        catalogFingerprint: fingerprint,
                        occasion: requestOccasion,
                        response: response
                    ),
                    for: accountScope
                )
            }
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = stateBeforeLoading
            } else {
                let message = Self.message(for: error)
                state = Self.retainingLoadedRecommendation(
                    from: stateBeforeLoading,
                    afterRefreshFailure: message,
                    refresh: refresh
                ) ?? .failed(message: message)
            }
        }
    }

    /// Advance to the next alternate look (wraps around). No-op unless loaded.
    func showAnother() {
        guard case .loaded(var recommendation) = state, recommendation.hasAlternates else { return }
        recommendation.index = (recommendation.index + 1) % recommendation.looks.count
        state = .loaded(recommendation)
    }

    /// Record the currently shown look as worn: persists an `Outfit` and a
    /// per-item `WearLog` (item + outfit) so it feeds tomorrow's anti-repeat.
    @discardableResult
    func wearCurrent() throws -> Bool {
        guard case .loaded(let recommendation) = state else { return false }
        guard !recommendation.wasWornToday else { return false }
        let look = recommendation.current
        try store.recordWear(
            items: look.items,
            occasion: recommendation.occasion,
            rationale: look.rationale,
            colorStory: recommendation.colorStory,
            date: now()
        )
        var updated = recommendation
        updated.markCurrentWorn()
        state = .loaded(updated)
        return true
    }

    // MARK: - Mapping

    /// Resolve Aria's id arrays back to `Item`s. The backend already guarantees
    /// every id is from the submitted catalog, but we resolve defensively and
    /// keep only looks that still have at least two items.
    private func resolve(
        _ response: RecommendResponse,
        catalog: [Item],
        generatedAt: Date,
        isCached: Bool,
        wornItemIDSetsToday: Set<Set<UUID>>
    ) -> State {
        var byID: [String: Item] = [:]
        for item in catalog { byID[item.id.uuidString] = item }

        func look(_ ids: [String], rationale: String) -> Look? {
            let items = ids.compactMap { byID[$0] }
            guard items.count >= Self.minimumCatalogItems else { return nil }
            return Look(items: items, rationale: rationale)
        }

        guard let primary = look(response.itemIds, rationale: response.rationale) else {
            return .failed(message: "Aria's pick didn't match your wardrobe. Try again.")
        }
        let alternates = response.alternates.compactMap { look($0.itemIds, rationale: $0.rationale) }

        return .loaded(Recommendation(
            occasion: response.occasion,
            colorStory: response.colorStory,
            looks: [primary] + alternates,
            generatedAt: generatedAt,
            isCached: isCached,
            wornItemIDSetsToday: wornItemIDSetsToday
        ))
    }

    private func wornItemIDSetsToday(
        among outfits: [Outfit],
        at date: Date
    ) -> Set<Set<UUID>> {
        var result: Set<Set<UUID>> = []
        for outfit in outfits where calendar.isDate(outfit.createdAt, inSameDayAs: date) {
            result.insert(Set(outfit.items.map(\.id)))
        }
        return result
    }

    private static func retainingLoadedRecommendation(
        from previousState: State,
        afterRefreshFailure message: String,
        refresh: Bool
    ) -> State? {
        guard refresh, case .loaded(var recommendation) = previousState else { return nil }
        recommendation.refreshFailureMessage = message
        return .loaded(recommendation)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case let issue as RecommendRequestValidationIssue:
            return issue.recoveryMessage
        case let authorizationError as AppAttestAuthorizationError:
            return authorizationError.localizedDescription
        case RecommendError.http(let status, _):
            switch status {
            case 401, 403:
                return "Styling isn’t available in this build. Please update the app and try again."
            case 429:
                return "Aria is receiving a lot of requests right now. Please wait a moment and try again."
            case 500...599:
                return "Aria is temporarily unavailable. Your wardrobe is safe on this device. Please try again."
            default:
                return "Aria couldn’t finish this look. Your wardrobe is safe on this device. Please try again."
            }
        case RecommendError.decoding:
            return "Aria returned a look the app couldn’t display. Please try again."
        case RecommendError.invalidResponse:
            return "Aria didn’t return a usable look. Please try again."
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You appear to be offline. Reconnect to style a new look. Any look saved earlier today remains stored on this device."
            case .timedOut:
                return "Styling took too long. Check your connection and try again."
            default:
                return "Aria couldn’t be reached. Check your connection and try again."
            }
        default:
            return "Aria couldn’t finish this look. Your wardrobe is safe on this device. Please try again."
        }
    }
}
