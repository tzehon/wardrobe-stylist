import Foundation

/// Pure mapping from wardrobe items to the compact, text-only payload Aria needs.
///
/// Lives outside `Gmail/` (no network, no read-only-guard surface) and is
/// protocol-driven so it unit-tests without SwiftData. Deliberately drops images
/// and purchase metadata — only ids + style attributes cross to the backend
/// (hybrid-privacy rule).
protocol StylableItem {
    var stylableID: UUID { get }
    var name: String { get }
    var category: String { get }
    var brand: String? { get }
    var colors: [String] { get }
    var material: String? { get }
}

extension Item: StylableItem {
    var stylableID: UUID { id }
}

enum CatalogCompactor {
    /// Map items to `RecommendCatalogItem`s, keyed by the item's UUID string so
    /// the ids Aria echoes back resolve unambiguously.
    static func compact(_ items: [some StylableItem]) -> [RecommendCatalogItem] {
        items.map { item in
            RecommendCatalogItem(
                id: item.stylableID.uuidString,
                name: item.name,
                category: item.category,
                brand: item.brand,
                colors: item.colors,
                material: item.material
            )
        }
    }
}
