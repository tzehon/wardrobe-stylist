import Testing

@testable import Wardrobe

@MainActor
struct WardrobeAccountScopeTests {
    @Test func onlyDeviceLocalScopeIsUsedAndAllLocalRowsAreVisible() {
        let active = Item(name: "Shirt", category: "top")
        let archived = Item(name: "Coat", category: "outerwear", isArchived: true)
        let outfit = Outfit(items: [active])
        let wear = WearLog(item: active, outfit: outfit)

        #expect(WardrobeAccountScope.deviceLocal.rawValue == "device-local:v1")
        #expect(WardrobeAccountFilter.visibleItems(
            from: [active, archived], in: .deviceLocal
        ).count == 2)
        #expect(WardrobeAccountFilter.styleableItems(
            from: [active, archived], in: .deviceLocal
        ).map(\.id) == [active.id])
        #expect(WardrobeAccountFilter.isVisible(outfit, in: .deviceLocal))
        #expect(WardrobeAccountFilter.isVisible(wear, in: .deviceLocal))
    }
}
