import Foundation
import Observation
import SwiftData

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
        var index: Int = 0

        var current: Look { looks[index] }
        var hasAlternates: Bool { looks.count > 1 }
    }

    enum State {
        case idle
        case loading
        case loaded(Recommendation)
        case emptyCatalog
        case failed(message: String)
    }

    var state: State = .idle

    private let recommendClient: RecommendClient
    private let modelContext: ModelContext
    private let now: () -> Date

    /// An outfit needs at least this many items to be worth recommending.
    private static let minimumCatalogItems = 2

    init(
        recommendClient: RecommendClient,
        modelContext: ModelContext,
        now: @escaping () -> Date = Date.init
    ) {
        self.recommendClient = recommendClient
        self.modelContext = modelContext
        self.now = now
    }

    /// Fetch a fresh recommendation from Aria.
    func recommend(occasion: String? = nil) async {
        // 1. Snapshot the catalog + wear history up front, before any await.
        let items: [Item]
        let recentlyWornIDs: [String]
        do {
            items = try modelContext.fetch(FetchDescriptor<Item>())
            let wears = try modelContext.fetch(FetchDescriptor<WearLog>())
            recentlyWornIDs = WearHistory.recentlyWornIDs(
                from: wears, since: WearHistory.cutoff(from: now())
            )
        } catch {
            state = .failed(message: "Couldn't read your wardrobe: \(error.localizedDescription)")
            return
        }

        guard items.count >= Self.minimumCatalogItems else {
            state = .emptyCatalog
            return
        }

        state = .loading
        let request = RecommendRequest(
            items: CatalogCompactor.compact(items),
            recentlyWornIds: recentlyWornIDs,
            occasion: occasion
        )

        do {
            let response = try await recommendClient.recommend(request)
            state = resolve(response, catalog: items)
        } catch {
            state = .failed(message: Self.message(for: error))
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
    func wearCurrent() {
        guard case .loaded(let recommendation) = state else { return }
        let look = recommendation.current
        let outfit = Outfit(
            createdAt: now(),
            occasion: recommendation.occasion,
            rationale: look.rationale,
            colorStory: recommendation.colorStory,
            items: look.items
        )
        modelContext.insert(outfit)
        for item in look.items {
            modelContext.insert(WearLog(date: now(), item: item, outfit: outfit))
        }
        try? modelContext.save()
    }

    // MARK: - Mapping

    /// Resolve Aria's id arrays back to `Item`s. The backend already guarantees
    /// every id is from the submitted catalog, but we resolve defensively and
    /// keep only looks that still have at least two items.
    private func resolve(_ response: RecommendResponse, catalog: [Item]) -> State {
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
            looks: [primary] + alternates
        ))
    }

    private static func message(for error: Error) -> String {
        switch error {
        case RecommendError.http(let status, _):
            return "The stylist service returned an error (\(status)). Please try again."
        case RecommendError.decoding:
            return "Couldn't read Aria's response. Please try again."
        case RecommendError.invalidResponse:
            return "No response from the stylist service."
        default:
            return error.localizedDescription
        }
    }
}
