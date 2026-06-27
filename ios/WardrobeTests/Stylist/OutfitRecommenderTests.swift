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

    private static func seedCatalog(_ context: ModelContext) {
        context.insert(Item(id: idA, name: "Oversized Tee", category: "top", source: .photo))
        context.insert(Item(id: idB, name: "Slim Trouser", category: "bottom", source: .photo))
        context.insert(Item(id: idC, name: "Suede Loafers", category: "shoe", source: .photo))
        try? context.save()
    }

    private static func makeRecommender(_ context: ModelContext) -> OutfitRecommender {
        OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: backendURL,
                deviceToken: "test-device-token",
                session: URLProtocolStub.makeSession()
            ),
            modelContext: context,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }

    nonisolated private static func ok(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
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

    @Test func recommendResolvesIdsToItems() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        Self.seedCatalog(context)

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

    @Test func showAnotherCyclesThroughAlternates() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        Self.seedCatalog(context)

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
        Self.seedCatalog(context)

        let responseBody = Self.body(itemIds: [Self.idA, Self.idB])
        URLProtocolStub.install { request in (Self.ok(for: request), Data(responseBody.utf8)) }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()
        recommender.wearCurrent()

        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        #expect(outfits.count == 1)
        #expect(outfits.first?.occasion == "relaxed weekend")
        #expect(outfits.first?.items.count == 2)

        let wears = try context.fetch(FetchDescriptor<WearLog>())
        #expect(wears.count == 2)  // one per item
        #expect(Set(wears.compactMap { $0.item?.id }) == [Self.idA, Self.idB])
    }

    @Test func dropsItemsNotInCatalogAndKeepsValidLook() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        Self.seedCatalog(context)

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
        try? context.save()

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
        Self.seedCatalog(context)

        URLProtocolStub.install { request in
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 502, httpVersion: "HTTP/1.1", headerFields: nil
            )!
            return (resp, Data(#"{"detail": "bad"}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let recommender = Self.makeRecommender(context)
        await recommender.recommend()

        guard case .failed = recommender.state else {
            Issue.record("Expected failed, got \(recommender.state)")
            return
        }
    }
}
