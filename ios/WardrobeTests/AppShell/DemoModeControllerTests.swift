import Foundation
import SwiftData
import Testing
@testable import Wardrobe

@MainActor
@Suite("Offline demo mode")
struct DemoModeControllerTests {
    @Test func fictionalDefinitionsAndLookAreDeterministicAndSafe() {
        #expect(DemoWardrobe.items.count == 7)
        #expect(Set(DemoWardrobe.items.map(\.id)).count == DemoWardrobe.items.count)
        #expect(DemoWardrobe.todayLook.itemIDs == [
            UUID(uuidString: "D3A00000-0000-4000-8000-000000000001")!,
            UUID(uuidString: "D3A00000-0000-4000-8000-000000000002")!,
            UUID(uuidString: "D3A00000-0000-4000-8000-000000000003")!,
            UUID(uuidString: "D3A00000-0000-4000-8000-000000000004")!,
        ])
        #expect(Set(DemoWardrobe.todayLook.itemIDs).isSubset(of: Set(DemoWardrobe.items.map(\.id))))
        #expect(Set(DemoWardrobe.recentLook.itemIDs).isSubset(of: Set(DemoWardrobe.items.map(\.id))))
        #expect(DemoWardrobe.items.allSatisfy {
            $0.brand.contains("Fictional")
                || $0.brand.contains("Imaginary")
                || $0.brand == "Studio Example"
                || $0.brand == "Example Receipt Shop"
        })
    }

    @Test func enteringSeedsOnlyAnIsolatedInMemoryContainer() throws {
        let realContainer = try ModelContainerFactory.makeInMemory()
        let realContext = ModelContext(realContainer)
        let realItem = Item(name: "My Real Coat", category: "outerwear", source: .manual)
        realContext.insert(realItem)
        try realContext.save()

        let controller = DemoModeController()
        #expect(controller.enter())
        let demoSession = try #require(controller.session)
        let demoContext = ModelContext(demoSession.container)
        let demoItems = try demoContext.fetch(FetchDescriptor<Item>())

        #expect(demoItems.map(\.id).sorted(by: Self.sortUUIDs) == DemoWardrobe.items.map(\.id).sorted(by: Self.sortUUIDs))
        #expect(demoItems.allSatisfy { item in
            item.sourceMsgId == nil
                && item.imageURL == nil
                && item.imageData == nil
        })
        #expect(demoItems.filter { $0.source == .manual }.allSatisfy {
            $0.accountSubjectKey == nil
        })
        #expect(demoItems.filter { $0.source == .email }.count == 1)
        #expect(demoItems.filter { $0.reviewState == .pendingReview }.count == 1)
        #expect(demoItems.first { $0.source == .email }?.extractionConfidence == .medium)
        #expect(demoItems.first { $0.source == .email }?.sourceMsgId == nil)
        #expect(demoItems.first { $0.source == .email }?.accountSubjectKey
            == WardrobeAccountScope.deviceLocal.rawValue)
        let demoOutfits = try demoContext.fetch(FetchDescriptor<Outfit>())
        let demoWearLogs = try demoContext.fetch(FetchDescriptor<WearLog>())
        #expect(demoOutfits.map(\.id) == [DemoWardrobe.recentLookID])
        #expect(demoOutfits[0].accountSubjectKey == WardrobeAccountScope.deviceLocal.rawValue)
        #expect(Set(demoOutfits[0].items.map(\.id)) == Set(DemoWardrobe.recentLook.itemIDs))
        #expect(demoWearLogs.count == DemoWardrobe.recentLook.itemIDs.count)
        #expect(demoWearLogs.allSatisfy { $0.outfit?.id == DemoWardrobe.recentLookID })
        #expect(demoWearLogs.allSatisfy {
            $0.accountSubjectKey == WardrobeAccountScope.deviceLocal.rawValue
        })
        #expect(try realContext.fetch(FetchDescriptor<Item>()).map(\.name) == ["My Real Coat"])
        #expect(try realContext.fetchCount(FetchDescriptor<Outfit>()) == 0)
        #expect(try realContext.fetchCount(FetchDescriptor<WearLog>()) == 0)
    }

    @Test func demoEditsNeverTouchRealRowsAndAreDiscardedOnExit() throws {
        let realContainer = try ModelContainerFactory.makeInMemory()
        let realContext = ModelContext(realContainer)
        realContext.insert(Item(name: "Private Wardrobe Item", category: "top"))
        try realContext.save()

        var createdContainers = 0
        let controller = DemoModeController(makeContainer: {
            createdContainers += 1
            return try ModelContainerFactory.makeInMemory()
        })

        #expect(controller.enter())
        let firstSession = try #require(controller.session)
        let firstContext = ModelContext(firstSession.container)
        let removed = try #require(firstContext.fetch(FetchDescriptor<Item>()).first)
        firstContext.delete(removed)
        firstContext.insert(Item(name: "Temporary Demo Edit", category: "accessory"))
        try firstContext.save()
        #expect(try firstContext.fetch(FetchDescriptor<Item>()).count == DemoWardrobe.items.count)

        controller.exit()
        #expect(!controller.isActive)
        #expect(controller.session == nil)
        #expect(try realContext.fetch(FetchDescriptor<Item>()).map(\.name) == ["Private Wardrobe Item"])

        #expect(controller.enter())
        let secondSession = try #require(controller.session)
        #expect(firstSession !== secondSession)
        #expect(createdContainers == 2)
        let restoredNames = try ModelContext(secondSession.container)
            .fetch(FetchDescriptor<Item>())
            .map(\.name)
        #expect(!restoredNames.contains("Temporary Demo Edit"))
        #expect(Set(restoredNames) == Set(DemoWardrobe.items.map(\.name)))
    }

    @Test func enteringAnActiveDemoIsIdempotent() throws {
        var containerCreations = 0
        let controller = DemoModeController(makeContainer: {
            containerCreations += 1
            return try ModelContainerFactory.makeInMemory()
        })

        #expect(controller.enter())
        let first = try #require(controller.session)
        #expect(controller.enter())
        #expect(controller.session === first)
        #expect(containerCreations == 1)
    }

    @Test func destructiveResetReplacesOnlyDemoDataAndKeepsRealStoreUntouched() throws {
        let realContainer = try ModelContainerFactory.makeInMemory()
        let realContext = ModelContext(realContainer)
        realContext.insert(Item(name: "Keep Me", category: "dress"))
        try realContext.save()

        let controller = DemoModeController()
        #expect(controller.enter())
        let originalSession = try #require(controller.session)
        let demoContext = ModelContext(originalSession.container)
        for item in try demoContext.fetch(FetchDescriptor<Item>()) {
            demoContext.delete(item)
        }
        try demoContext.save()
        #expect(try demoContext.fetchCount(FetchDescriptor<Item>()) == 0)

        #expect(controller.reset())
        let resetSession = try #require(controller.session)
        #expect(resetSession !== originalSession)
        #expect(try ModelContext(resetSession.container).fetchCount(FetchDescriptor<Item>()) == 7)
        #expect(try ModelContext(resetSession.container).fetchCount(FetchDescriptor<Outfit>()) == 1)
        #expect(try ModelContext(resetSession.container).fetchCount(FetchDescriptor<WearLog>()) == 4)
        #expect(try realContext.fetch(FetchDescriptor<Item>()).map(\.name) == ["Keep Me"])
    }

    @Test func constructionAndEntryHaveNoConnectedFeatureHooks() throws {
        // The only injectable closures are local container construction and
        // local seeding. A counter proves that entering cannot invoke an
        // unlisted Google, backend, background, or notification dependency.
        var containerCalls = 0
        var seedCalls = 0
        let controller = DemoModeController(
            automaticallyEnter: false,
            makeContainer: {
                containerCalls += 1
                return try ModelContainerFactory.makeInMemory()
            },
            seed: { context in
                seedCalls += 1
                try DemoWardrobe.seed(into: context)
            }
        )

        #expect(containerCalls == 0)
        #expect(seedCalls == 0)
        #expect(controller.enter())
        #expect(containerCalls == 1)
        #expect(seedCalls == 1)
    }

    @Test func connectedCapabilitiesAreUnconditionallyDisabled() {
        #expect(DemoConnectedCapability.allCases.count == 5)
        #expect(DemoConnectedCapability.allCases.allSatisfy {
            !DemoConnectedFeaturePolicy.isEnabled($0)
        })
    }

    @Test func reviewerLaunchArgumentIsExactAndCanStartImmediately() {
        #expect(DemoLaunchPolicy.isRequested(arguments: ["Wardrobe", "--wardrobe-demo"]))
        #expect(!DemoLaunchPolicy.isRequested(arguments: ["Wardrobe", "wardrobe-demo"]))
        #expect(!DemoLaunchPolicy.isRequested(arguments: ["Wardrobe", "--wardrobe-demo=true"]))

        var containerCalls = 0
        let controller = DemoModeController(
            automaticallyEnter: true,
            makeContainer: {
                containerCalls += 1
                return try ModelContainerFactory.makeInMemory()
            }
        )
        #expect(controller.isActive)
        #expect(controller.session != nil)
        #expect(containerCalls == 1)
    }

    @Test func localUITestLaunchArgumentIsExact() {
        #expect(LocalUITestLaunchPolicy.isRequested(arguments: ["Wardrobe", "--wardrobe-ui-testing-local"]))
        #expect(!LocalUITestLaunchPolicy.isRequested(arguments: ["Wardrobe", "wardrobe-ui-testing-local"]))
        #expect(!LocalUITestLaunchPolicy.isRequested(arguments: ["Wardrobe", "--wardrobe-ui-testing-local=true"]))
    }

    @Test func creationFailureLeavesNoDemoSessionAndCanBeCleared() {
        struct TestFailure: Error {}
        let controller = DemoModeController(makeContainer: { throw TestFailure() })

        #expect(!controller.enter())
        #expect(!controller.isActive)
        #expect(controller.session == nil)
        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected failed demo state")
            return
        }
        #expect(failure.diagnostic.contains("TestFailure"))
        #expect(DemoModeFailure.userMessage.contains("not changed"))

        controller.clearFailure()
        guard case .inactive = controller.state else {
            Issue.record("Expected inactive state after clearing the error")
            return
        }
    }

    private static func sortUUIDs(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
