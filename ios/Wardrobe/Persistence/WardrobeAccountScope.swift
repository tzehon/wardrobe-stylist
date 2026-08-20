import Foundation

/// Compatibility value used by the existing view and cache interfaces.
/// The candidate has exactly one device-local namespace.
struct WardrobeAccountScope: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let deviceLocal = Self(rawValue: "device-local:v1")
}

enum WardrobeAccountFilter {
    static func isVisible(_: Item, in _: WardrobeAccountScope) -> Bool { true }
    static func isVisible(_: Outfit, in _: WardrobeAccountScope) -> Bool { true }
    static func isVisible(_: WearLog, in _: WardrobeAccountScope) -> Bool { true }

    static func visibleItems(
        from items: [Item],
        in _: WardrobeAccountScope
    ) -> [Item] {
        items
    }

    static func styleableItems(
        from items: [Item],
        in _: WardrobeAccountScope
    ) -> [Item] {
        items.filter { !$0.isArchived }
    }

    static func visibleOutfits(
        from outfits: [Outfit],
        in _: WardrobeAccountScope
    ) -> [Outfit] {
        outfits
    }

    static func visibleWearLogs(
        from wearLogs: [WearLog],
        in _: WardrobeAccountScope
    ) -> [WearLog] {
        wearLogs
    }
}
