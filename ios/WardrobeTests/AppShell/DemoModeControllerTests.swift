import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct DemoModeControllerTests {
    @Test func demoSeedsOnlyManualDeviceLocalItemsAndResetsDisposableStore() throws {
        let controller = DemoModeController()
        #expect(controller.enter())
        let first = try #require(controller.session)
        let context = ModelContext(first.container)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == DemoWardrobe.items.count)
        #expect(items.allSatisfy { $0.source == .manual })
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 1)

        context.insert(Item(name: "Temporary", category: "top"))
        try context.save()
        #expect(controller.reset())
        let reset = try #require(controller.session)
        #expect(ObjectIdentifier(first) != ObjectIdentifier(reset))
        let resetContext = ModelContext(reset.container)
        #expect(try resetContext.fetchCount(FetchDescriptor<Item>()) == DemoWardrobe.items.count)
    }

    @Test func allDemoConnectedCapabilitiesFailClosed() {
        #expect(DemoConnectedCapability.allCases.allSatisfy {
            !DemoConnectedFeaturePolicy.isEnabled($0)
        })
    }
}
