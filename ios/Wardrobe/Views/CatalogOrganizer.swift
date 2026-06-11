import Foundation

/// Anything the catalog can group into category sections. Keeping the organizer
/// generic over this protocol (rather than hard-wiring `Item`) lets the grouping
/// logic be unit-tested with lightweight stubs — no SwiftData container needed.
protocol CatalogCategorizable {
    var category: String { get }
    var name: String { get }
}

extension Item: CatalogCategorizable {}

/// One category's worth of items, ready to render as a section.
struct CatalogSection<Element>: Identifiable {
    let category: String
    let items: [Element]
    var id: String { category }
}

/// Pure, deterministic grouping of catalog items into ordered category sections.
///
/// "Dynamic categories": sections are derived from the data, so any category the
/// extractor emits shows up automatically. Known fashion categories sort in a
/// stable canonical order; anything else (a new/unexpected category, or blank →
/// `uncategorized`) sorts after them, alphabetically.
enum CatalogOrganizer {

    /// Display order for the controlled fashion vocabulary (see `Item.category`).
    static let canonicalOrder: [String] = [
        "top", "bottom", "dress", "outerwear", "shoe", "bag", "jewelry", "accessory",
    ]

    static func sections<Element: CatalogCategorizable>(
        from items: [Element]
    ) -> [CatalogSection<Element>] {
        Dictionary(grouping: items) { normalize($0.category) }
            .map { category, members in
                CatalogSection(
                    category: category,
                    items: members.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted(by: precedes)
    }

    /// Lower-cased, trimmed; empty categories collapse to a single `uncategorized` bucket.
    private static func normalize(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "uncategorized" : trimmed
    }

    /// Canonical categories first (in vocabulary order), then everything else A–Z.
    private static func precedes<E>(_ a: CatalogSection<E>, _ b: CatalogSection<E>) -> Bool {
        switch (canonicalOrder.firstIndex(of: a.category),
                canonicalOrder.firstIndex(of: b.category)) {
        case let (x?, y?): return x < y
        case (_?, nil):    return true
        case (nil, _?):    return false
        case (nil, nil):
            return a.category.localizedCaseInsensitiveCompare(b.category) == .orderedAscending
        }
    }
}

/// Presentation helpers for a category string — pluralized titles + SF Symbols
/// used for section headers and image placeholders. Falls back gracefully for
/// categories outside the known vocabulary.
enum CatalogCategoryStyle {

    static func title(_ category: String) -> String {
        switch category {
        case "top":          return "Tops"
        case "bottom":       return "Bottoms"
        case "dress":        return "Dresses"
        case "outerwear":    return "Outerwear"
        case "shoe":         return "Shoes"
        case "bag":          return "Bags"
        case "jewelry":      return "Jewelry"
        case "accessory":    return "Accessories"
        case "uncategorized": return "Uncategorized"
        default:             return category.capitalized
        }
    }

    static func symbol(_ category: String) -> String {
        switch category {
        case "top":                          return "tshirt"
        case "bottom", "dress", "outerwear": return "hanger"
        case "shoe":                         return "shoe"
        case "bag":                          return "bag"
        case "jewelry":                      return "sparkles"
        case "accessory":                    return "eyeglasses"
        default:                             return "hanger"
        }
    }
}
