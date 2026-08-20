import Foundation
import SwiftData
import Testing

@testable import Wardrobe

/// Tests for the recommend → resolve → persist flow with a stubbed backend and
/// an in-memory SwiftData container. The URLProtocol handler must not capture
/// `self` (it runs off the main actor) — everything it needs is a local Sendable
/// value captured before `install`.
@MainActor
struct OutfitRecommenderTests {

    private actor SuspendedPrivacyGate: PrivacyGateChecking {
        private var continuation: CheckedContinuation<Void, Never>?
        private var decisionCount = 0

        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            decisionCount += 1
            if decisionCount == 1 {
                await withCheckedContinuation { continuation = $0 }
            }
            return .allowed
        }

        func hasEntered() -> Bool { decisionCount > 0 }

        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    private struct AllowPrivacyGate: PrivacyGateChecking {
        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            .allowed
        }
    }

    private struct DenyPrivacyGate: PrivacyGateChecking {
        let denial: PrivacyGateDenial

        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            .denied(denial)
        }
    }

    private struct FailingBackendAuthorization: BackendAuthorizing {
        let error: AppAttestAuthorizationError

        func accessToken(rejecting rejectedToken: String?) async throws -> String {
            throw error
        }
    }

    @MainActor
    private final class MemoryDailyLookCache: DailyLookCaching {
        var entries: [WardrobeAccountScope: DailyLookCacheEntry] = [:]
        private(set) var removedScopes: [WardrobeAccountScope] = []

        func load(for accountScope: WardrobeAccountScope) -> DailyLookCacheEntry? {
            entries[accountScope]
        }

        func save(_ entry: DailyLookCacheEntry, for accountScope: WardrobeAccountScope) {
            entries[accountScope] = entry
        }

        func remove(for accountScope: WardrobeAccountScope) {
            removedScopes.append(accountScope)
            entries.removeValue(forKey: accountScope)
        }
    }

    nonisolated private static let backendURL = URL(string: "http://test.local")!

    // Fixed item ids so the stubbed response can reference them.
    nonisolated private static let idA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    nonisolated private static let idB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    nonisolated private static let idC = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!

    private static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Item.self, Outfit.self, WearLog.self, configurations: config
        )
    }

    private static func seedCatalog(_ context: ModelContext) throws {
        context.insert(Item(id: idA, name: "Oversized Tee", category: "top", source: .photo))
        context.insert(Item(id: idB, name: "Slim Trouser", category: "bottom", source: .photo))
        context.insert(Item(id: idC, name: "Suede Loafers", category: "shoe", source: .photo))
        try context.save()
    }

    private static func makeRecommender(
        _ context: ModelContext,
        dailyLookCache: any DailyLookCaching = DisabledDailyLookCache(),
        accountScope: WardrobeAccountScope = .deviceLocal,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) }
    ) -> OutfitRecommender {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: backendURL,
                authorization: StaticBackendAuthorization(token: "test-device-token"),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            accountScope: accountScope,
            dailyLookCache: dailyLookCache,
            calendar: calendar,
            now: now
        )
    }

    private final class FailingStore: WardrobeStoring {
        enum FixtureError: Error { case saveFailed }

        private(set) var recordWearCalls = 0

        func addItem(_ input: ManualItemInput) throws -> Item {
            Item(name: input.name, category: input.category, source: input.source)
        }
        func updateItem(_ item: Item, with input: ItemUpdateInput) throws {}
        func deleteItem(_ item: Item) throws {}
        func setFavorite(_ isFavorite: Bool, for item: Item) throws {}
        func setArchived(_ isArchived: Bool, for item: Item) throws {}
        func acceptPendingItems(_ items: [Item], reviewedAt: Date) throws {}

        func recordWear(
            items: [Item],
            occasion: String?,
            rationale: String?,
            colorStory: String?,
            date: Date
        ) throws -> Outfit {
            recordWearCalls += 1
            throw WardrobePersistenceError(operation: .recordWear, underlying: FixtureError.saveFailed)
        }

        func rateOutfit(_ outfit: Outfit, feedback: Int) throws {}
    }

    nonisolated private static func ok(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    nonisolated private static func wait(
        for semaphore: DispatchSemaphore,
        timeout: TimeInterval
    ) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }

    nonisolated private static func body(
        itemIds: [UUID], alternates: [[UUID]] = []
    ) -> String {
        let primary = itemIds.map { "\"\($0.uuidString)\"" }.joined(separator: ", ")
        let alts = alternates.map { ids -> String in
            let joined = ids.map { "\"\($0.uuidString)\"" }.joined(separator: ", ")
            return "{\"item_ids\": [\(joined)], \"rationale\": \"alt\"}"
        }.joined(separator: ", ")
        return """
        {"occasion": "relaxed weekend", "color_story": "soft neutrals",
         "rationale": "Easy and cohesive.", "item_ids": [\(primary)],
         "alternates": [\(alts)], "usage": {"input_tokens": 100, "output_tokens": 40}}
        """
    }

    // MARK: - Tests

    @Test func stylingWithoutConsentReadsNoCatalogAndMakesNoBackendRequest() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let recommender = OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: Self.backendURL,
                authorization: StaticBackendAuthorization(token: "test-device-token"),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            privacyGate: DenyPrivacyGate(denial: .stylingConsentRequired)
        )
        URLProtocolStub.install { _ in
            Issue.record("A denied recommendation must not make a request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        await recommender.recommend()

        guard case .consentRequired(let denial) = recommender.state else {
            Issue.record("Expected consentRequired, got \(recommender.state)")
            return
        }
        #expect(denial == .stylingConsentRequired)
        #expect(URLProtocolStub.captured.isEmpty)
    }

    @Test func unsupportedAppAttestShowsFriendlyFailureWithoutARequest() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let error = AppAttestAuthorizationError.unsupportedDevice
        let recommender = OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: Self.backendURL,
                authorization: FailingBackendAuthorization(error: error),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            privacyGate: AllowPrivacyGate()
        )
        URLProtocolStub.install { _ in
            Issue.record("Unsupported App Attest must fail before the styling request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        await recommender.recommend()

        guard case .failed(let message) = recommender.state else {
            Issue.record("Expected friendly App Attest failure, got \(recommender.state)")
            return
        }
        #expect(message == error.localizedDescription)
        #expect(message.contains("local wardrobe and Demo Mode still work"))
        #expect(URLProtocolStub.captured.isEmpty)
    }

    @Test func recommendResolvesIdsToItems() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)

        let responseBody = Self.body(itemIds: [Self.idA, Self.idB, Self.idC])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .loaded(let rec) = recommender.state else {
            Issue.record("Expected loaded, got \(recommender.state)")
            return
        }
        #expect(rec.occasion == "relaxed weekend")
        #expect(rec.current.items.map(\.id) == [Self.idA, Self.idB, Self.idC])
        #expect(rec.current.items.first?.name == "Oversized Tee")
    }

    @Test func sameDayRecommendationUsesCacheWithoutASecondBackendCall() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }
        let recommender = Self.makeRecommender(context, dailyLookCache: cache)

        await recommender.recommend(occasion: " Work ")
        guard case .loaded(let fetched) = recommender.state else {
            Issue.record("Expected fetched recommendation")
            return
        }
        #expect(!fetched.isCached)
        #expect(URLProtocolStub.captured.count == 1)

        await recommender.recommend(occasion: "work")
        guard case .loaded(let cached) = recommender.state else {
            Issue.record("Expected cached recommendation")
            return
        }
        #expect(cached.isCached)
        #expect(cached.generatedAt == fetched.generatedAt)
        #expect(URLProtocolStub.captured.count == 1)
    }

    @Test func emptyOccasionRestoresOccasionSpecificCacheAfterRelaunch() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let first = Self.makeRecommender(context, dailyLookCache: cache)
        await first.recommend(occasion: "Dinner")
        let relaunched = Self.makeRecommender(context, dailyLookCache: cache)
        await relaunched.recommend()

        guard case .loaded(let restored) = relaunched.state else {
            Issue.record("Expected cached recommendation after relaunch")
            return
        }
        #expect(restored.isCached)
        #expect(URLProtocolStub.captured.count == 1)
    }

    @Test func explicitRefreshBypassesAndReplacesTheDailyCache() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let firstBody = Self.body(itemIds: [Self.idA, Self.idB])
        let replacementBody = Self.body(itemIds: [Self.idA, Self.idC])
        URLProtocolStub.install { request in
            let body = URLProtocolStub.captured.count == 1 ? firstBody : replacementBody
            return (Self.ok(for: request), Data(body.utf8))
        }
        defer { URLProtocolStub.reset() }
        let recommender = Self.makeRecommender(context, dailyLookCache: cache)

        await recommender.recommend()
        await recommender.recommend(refresh: true)

        guard case .loaded(let refreshed) = recommender.state else {
            Issue.record("Expected refreshed recommendation")
            return
        }
        #expect(!refreshed.isCached)
        #expect(refreshed.current.items.map(\.id) == [Self.idA, Self.idC])
        #expect(cache.entries[.deviceLocal]?.response.itemIds == [
            Self.idA.uuidString,
            Self.idC.uuidString,
        ])
        #expect(URLProtocolStub.captured.count == 2)

        let relaunched = Self.makeRecommender(context, dailyLookCache: cache)
        await relaunched.recommend()
        guard case .loaded(let restored) = relaunched.state else {
            Issue.record("Expected refreshed cache after relaunch")
            return
        }
        #expect(restored.isCached)
        #expect(restored.current.items.map(\.id) == [Self.idA, Self.idC])
        #expect(URLProtocolStub.captured.count == 2)
    }

    @Test func invalidResolvableCacheIsRemovedBeforeNetworkFallback() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let compact = CatalogCompactor.compact(
            WardrobeAccountFilter.visibleItems(
                from: try context.fetch(FetchDescriptor<Item>()),
                in: .deviceLocal
            )
        )
        cache.entries[.deviceLocal] = DailyLookCacheEntry(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            catalogFingerprint: DailyLookCatalogFingerprint.make(from: compact),
            occasion: nil,
            response: RecommendResponse(
                occasion: "invalid",
                colorStory: "none",
                rationale: "missing ids",
                itemIds: [UUID().uuidString, UUID().uuidString],
                alternates: [],
                usage: [:]
            )
        )
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context, dailyLookCache: cache)
        await recommender.recommend()

        guard case .loaded(let fetched) = recommender.state else {
            Issue.record("Expected network fallback")
            return
        }
        #expect(!fetched.isCached)
        #expect(cache.entries[.deviceLocal]?.response.itemIds == [
            Self.idA.uuidString,
            Self.idB.uuidString,
        ])
        #expect(cache.removedScopes == [.deviceLocal])
        #expect(URLProtocolStub.captured.count == 1)
    }

    @Test func overlappingRecommendationAttemptIsIgnoredBeforePrivacyGateReturns() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let gate = SuspendedPrivacyGate()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }
        let recommender = OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: Self.backendURL,
                authorization: StaticBackendAuthorization(token: "test-device-token"),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            privacyGate: gate,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let first = Task { await recommender.recommend() }
        while !(await gate.hasEntered()) { await Task.yield() }
        #expect(recommender.isRequestInFlight)
        await recommender.recommend(refresh: true)
        await gate.resume()
        await first.value

        #expect(URLProtocolStub.captured.count == 1)
        #expect(!recommender.isRequestInFlight)
    }

    @Test func cancellationAtPrivacyBoundaryLeavesIdleAndMakesNoRequestOrCacheWrite() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let gate = SuspendedPrivacyGate()
        URLProtocolStub.install { _ in
            Issue.record("A recommendation cancelled at the privacy boundary must not make a request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }
        let recommender = OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: Self.backendURL,
                authorization: StaticBackendAuthorization(token: "test-device-token"),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            privacyGate: gate,
            dailyLookCache: cache,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let request = Task { await recommender.recommend() }
        while !(await gate.hasEntered()) { await Task.yield() }
        request.cancel()
        await gate.resume()
        await request.value

        guard case .idle = recommender.state else {
            Issue.record("Cancellation should leave the pre-request idle state")
            return
        }
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(cache.entries.isEmpty)
        #expect(!recommender.isRequestInFlight)
    }

    @Test func cancellationDuringRefreshRestoresLoadedStateAndSkipsStaleCacheWrite() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseStarted = DispatchSemaphore(value: 0)
        let allowResponse = DispatchSemaphore(value: 0)
        let firstBody = Self.body(itemIds: [Self.idA, Self.idB])
        let staleBody = Self.body(itemIds: [Self.idA, Self.idC])
        URLProtocolStub.install { request in
            guard URLProtocolStub.captured.count > 1 else {
                return (Self.ok(for: request), Data(firstBody.utf8))
            }
            responseStarted.signal()
            allowResponse.wait()
            return (Self.ok(for: request), Data(staleBody.utf8))
        }
        defer {
            allowResponse.signal()
            URLProtocolStub.reset()
        }
        let recommender = Self.makeRecommender(context, dailyLookCache: cache)
        await recommender.recommend()
        guard case .loaded(let original) = recommender.state else {
            Issue.record("Expected the initial recommendation")
            return
        }

        let refresh = Task { await recommender.recommend(refresh: true) }
        let didStart = await Task.detached {
            Self.wait(for: responseStarted, timeout: 5)
        }.value
        guard didStart else {
            Issue.record("Timed out waiting for the refresh request")
            refresh.cancel()
            allowResponse.signal()
            await refresh.value
            return
        }
        refresh.cancel()
        allowResponse.signal()
        await refresh.value

        guard case .loaded(let restored) = recommender.state else {
            Issue.record("Cancellation should restore the previously loaded recommendation")
            return
        }
        #expect(restored.current.items.map(\.id) == original.current.items.map(\.id))
        #expect(restored.generatedAt == original.generatedAt)
        #expect(cache.entries[.deviceLocal]?.response.itemIds == [
            Self.idA.uuidString,
            Self.idB.uuidString,
        ])
        #expect(URLProtocolStub.captured.count == 2)
        #expect(!recommender.isRequestInFlight)
    }

    @Test func completionTimeIsUsedForCacheAndPresentation() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let completion = start.addingTimeInterval(120)
        var dates = [start, start, completion]
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }
        let recommender = Self.makeRecommender(
            context,
            dailyLookCache: cache,
            now: { dates.removeFirst() }
        )

        await recommender.recommend()

        guard case .loaded(let recommendation) = recommender.state else {
            Issue.record("Expected loaded recommendation")
            return
        }
        #expect(recommendation.generatedAt == completion)
        #expect(cache.entries[.deviceLocal]?.generatedAt == completion)
    }

    @Test func occasionIsLimitedBeforeItReachesTheBackendOrCache() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }
        let recommender = Self.makeRecommender(context, dailyLookCache: cache)

        await recommender.recommend(occasion: "  \(String(repeating: "x", count: 200))  ")

        let body = try #require(URLProtocolStub.capturedBodies.first)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let sentOccasion = try #require(json["occasion"] as? String)
        #expect(sentOccasion.count == StylingOccasion.maximumLength)
        #expect(sentOccasion == String(repeating: "x", count: StylingOccasion.maximumLength))
        #expect(cache.entries[.deviceLocal]?.occasionKey == sentOccasion)
    }

    @Test func cachedReloadRecognizesWornAlternateAndPreventsDuplicateSameDayWear() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseBody = Self.body(
            itemIds: [Self.idA, Self.idB],
            alternates: [[Self.idA, Self.idC]]
        )
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let first = Self.makeRecommender(context, dailyLookCache: cache)
        await first.recommend()
        first.showAnother()
        #expect(try first.wearCurrent())
        #expect(try context.fetch(FetchDescriptor<Outfit>()).count == 1)

        let relaunched = Self.makeRecommender(context, dailyLookCache: cache)
        await relaunched.recommend()
        guard case .loaded(let primary) = relaunched.state else {
            Issue.record("Expected cached recommendation")
            return
        }
        #expect(primary.isCached)
        #expect(!primary.wasWornToday)

        relaunched.showAnother()
        guard case .loaded(let alternate) = relaunched.state else {
            Issue.record("Expected cached alternate")
            return
        }
        #expect(alternate.wasWornToday)
        #expect(try relaunched.wearCurrent() == false)
        #expect(try context.fetch(FetchDescriptor<Outfit>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<WearLog>()).count == 2)
        #expect(URLProtocolStub.captured.count == 1)
    }

    @Test func catalogChangeInvalidatesTheDailyCache() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let cache = MemoryDailyLookCache()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }
        let recommender = Self.makeRecommender(context, dailyLookCache: cache)

        await recommender.recommend()
        context.insert(Item(name: "New jacket", category: "outerwear", source: .manual))
        try context.save()
        await recommender.recommend()

        #expect(URLProtocolStub.captured.count == 2)
    }

    @Test func recommendationExcludesArchivedItemsFromStylingBoundary() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        let acceptedA = Item(id: Self.idA, name: "Accepted tee", category: "top", source: .manual)
        let acceptedB = Item(id: Self.idB, name: "Accepted trouser", category: "bottom", source: .manual)
        let archivedID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let archived = Item(
            id: archivedID,
            name: "Archived jacket",
            category: "outerwear",
            source: .manual,
            isArchived: true
        )
        for item in [acceptedA, acceptedB, archived] {
            context.insert(item)
        }
        context.insert(WearLog(
            date: Date(timeIntervalSince1970: 1_699_999_000),
            item: archived,
            feedback: 1
        ))
        try context.save()

        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        await Self.makeRecommender(context).recommend()

        let body = try #require(URLProtocolStub.capturedBodies.first)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let payloadItems = try #require(json["items"] as? [[String: Any]])
        #expect(Set(payloadItems.compactMap { $0["id"] as? String }) == [
            Self.idA.uuidString,
            Self.idB.uuidString,
        ])
        #expect((json["recently_worn_ids"] as? [String]) == [])
        #expect((json["item_preferences"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test func archivedItemsCannotSatisfyMinimumStylingCatalog() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        context.insert(Item(id: Self.idA, name: "Accepted tee", category: "top", source: .manual))
        context.insert(Item(
            id: Self.idB,
            name: "Archived trouser",
            category: "bottom",
            source: .manual,
            isArchived: true
        ))
        context.insert(Item(
            id: Self.idC,
            name: "Archived shoes",
            category: "shoe",
            source: .manual,
            isArchived: true
        ))
        try context.save()
        URLProtocolStub.install { _ in
            Issue.record("Non-styleable items must not trigger a styling request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .emptyCatalog = recommender.state else {
            Issue.record("Expected an empty styleable catalog, got \(recommender.state)")
            return
        }
        #expect(URLProtocolStub.captured.isEmpty)
    }

    @Test func networkFailureUsesFriendlyOfflineCopyWithoutSystemDiagnostics() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        URLProtocolStub.install { _ in throw URLError(.notConnectedToInternet) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .failed(let message) = recommender.state else {
            Issue.record("Expected a friendly failed state, got \(recommender.state)")
            return
        }
        #expect(message == "You appear to be offline. Reconnect to style a new look. Any look saved earlier today remains stored on this device.")
        #expect(!message.contains("NSURLError"))
    }

    @Test func showAnotherCyclesThroughAlternates() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)

        let responseBody = Self.body(
            itemIds: [Self.idA, Self.idB],
            alternates: [[Self.idA, Self.idC]]
        )
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .loaded(let first) = recommender.state else {
            Issue.record("Expected loaded")
            return
        }
        #expect(first.hasAlternates)
        #expect(first.current.items.map(\.id) == [Self.idA, Self.idB])

        recommender.showAnother()
        guard case .loaded(let second) = recommender.state else {
            Issue.record("Expected loaded after showAnother")
            return
        }
        #expect(second.current.items.map(\.id) == [Self.idA, Self.idC])

        recommender.showAnother()  // wraps back to primary
        guard case .loaded(let third) = recommender.state else {
            Issue.record("Expected loaded after wrap")
            return
        }
        #expect(third.current.items.map(\.id) == [Self.idA, Self.idB])
    }

    @Test func wearCurrentPersistsOutfitAndWearLogs() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)

        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()
        try recommender.wearCurrent()

        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        #expect(outfits.count == 1)
        #expect(outfits.first?.occasion == "relaxed weekend")
        #expect(outfits.first?.items.count == 2)

        let wears = try context.fetch(FetchDescriptor<WearLog>())
        #expect(wears.count == 2)  // one per item
        #expect(Set(wears.compactMap { $0.item?.id }) == [Self.idA, Self.idB])
    }

    @Test func wearCurrentPropagatesFailureSoUISuccessCanRemainFalse() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)
        let failingStore = FailingStore()

        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: Self.backendURL,
                authorization: StaticBackendAuthorization(token: "test-device-token"),
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            store: failingStore,
            privacyGate: AllowPrivacyGate(),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        await recommender.recommend()
        let coordinator = WardrobeWriteCoordinator()
        var didMarkWorn = false

        coordinator.perform(
            operation: .recordWear,
            write: { _ = try recommender.wearCurrent() },
            onSuccess: { didMarkWorn = true }
        )

        #expect(failingStore.recordWearCalls == 1)
        #expect(!didMarkWorn)
        #expect(coordinator.error?.operation == .recordWear)
        #expect(try context.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WearLog>()).isEmpty)
    }

    @Test func dropsItemsNotInCatalogAndKeepsValidLook() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)

        // Backend already guards, but resolve defensively: an unknown id is dropped.
        let bogus = UUID()
        let responseBody = Self.body(itemIds: [Self.idA, Self.idB, bogus])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .loaded(let rec) = recommender.state else {
            Issue.record("Expected loaded")
            return
        }
        #expect(rec.current.items.map(\.id) == [Self.idA, Self.idB])
    }

    @Test func emptyCatalogShortCircuits() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        context.insert(Item(id: Self.idA, name: "Lonely Tee", category: "top", source: .photo))
        try context.save()

        // No stub installed — recommend() must not hit the network for a tiny catalog.
        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .emptyCatalog = recommender.state else {
            Issue.record("Expected emptyCatalog, got \(recommender.state)")
            return
        }
    }

    @Test func backendErrorSurfacesAsFailed() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        try Self.seedCatalog(context)

        URLProtocolStub.install { request in
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 502, httpVersion: "HTTP/1.1", headerFields: nil
            )!
            return (resp, Data(#"{"detail": "bad"}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .failed(let message) = recommender.state else {
            Issue.record("Expected failed, got \(recommender.state)")
            return
        }
        #expect(message == "Aria is temporarily unavailable. Your wardrobe is safe on this device. Please try again.")
        #expect(!message.contains("502"))
        #expect(!message.contains("bad"))
    }
}
