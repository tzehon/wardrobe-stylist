import Foundation

/// Anything the catalog can group, filter, and sort. Keeping the logic generic
/// over this protocol (rather than hard-wiring `Item`) lets it be unit-tested
/// with lightweight stubs — no SwiftData container needed.
protocol CatalogCategorizable {
    var category: String { get }
    var name: String { get }
    var brand: String? { get }
    var purchaseDate: Date? { get }
}

extension Item: CatalogCategorizable {}

/// One category's worth of items, ready to render as a section.
struct CatalogSection<Element>: Identifiable {
    let category: String
    let items: [Element]
    var id: String { category }
}

/// How items are ordered within a category section.
enum CatalogSortOrder: String, CaseIterable, Identifiable, Sendable {
    case recent
    case name
    case brand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return "Recently purchased"
        case .name:   return "Name (A–Z)"
        case .brand:  return "Brand"
        }
    }

    var symbol: String {
        switch self {
        case .recent: return "calendar"
        case .name:   return "textformat"
        case .brand:  return "tag"
        }
    }
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
        from items: [Element],
        sortedBy sort: CatalogSortOrder = .name
    ) -> [CatalogSection<Element>] {
        let grouped = Dictionary(grouping: items) { normalize($0.category) }
        var result: [CatalogSection<Element>] = []
        result.reserveCapacity(grouped.count)
        for (category, members) in grouped {
            result.append(CatalogSection(category: category, items: sorted(members, by: sort)))
        }
        return result.sorted { categoryPrecedes($0.category, $1.category) }
    }

    /// Orders items within a section. Ties fall back to name so the order is
    /// always fully determined (stable across runs). Comparisons are inlined
    /// (rather than calling a generic helper from inside the `sorted` closure) to
    /// avoid a non-Sendable `Element.Type` capture under Swift 6 strict concurrency.
    private static func sorted<E: CatalogCategorizable>(
        _ items: [E], by sort: CatalogSortOrder
    ) -> [E] {
        switch sort {
        case .name:
            return items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .brand:
            return items.sorted { lhs, rhs in
                let l = lhs.brand?.lowercased() ?? ""
                let r = rhs.brand?.lowercased() ?? ""
                if l != r {
                    if l.isEmpty != r.isEmpty { return !l.isEmpty }  // branded before brandless
                    return l < r
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .recent:
            return items.sorted { lhs, rhs in
                switch (lhs.purchaseDate, rhs.purchaseDate) {
                case let (a?, b?) where a != b: return a > b     // most recent first
                case (_?, nil): return true                       // dated before undated
                case (nil, _?): return false
                default:
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
        }
    }

    /// Lower-cased, trimmed; empty categories collapse to a single `uncategorized` bucket.
    private static func normalize(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "uncategorized" : trimmed
    }

    /// Canonical categories first (in vocabulary order), then everything else A–Z.
    /// Non-generic (compares the category strings) so the section-sort closure
    /// captures no `Element` metatype under Swift 6 strict concurrency.
    private static func categoryPrecedes(_ a: String, _ b: String) -> Bool {
        switch (canonicalOrder.firstIndex(of: a), canonicalOrder.firstIndex(of: b)) {
        case let (x?, y?): return x < y
        case (_?, nil):    return true
        case (nil, _?):    return false
        case (nil, nil):   return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }
}

/// Search + category filtering applied to catalog items before grouping.
enum CatalogFilter {

    static func apply<Element: CatalogCategorizable>(
        to items: [Element],
        search: String,
        category: String?
    ) -> [Element] {
        var result = items
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.name.lowercased().contains(query)
                    || (item.brand?.lowercased().contains(query) ?? false)
            }
        }
        if let category {
            let target = category.lowercased()
            result = result.filter {
                $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
            }
        }
        return result
    }

    /// Distinct categories present, in canonical display order — used to build
    /// the filter chips so they always reflect the actual catalog.
    static func availableCategories<Element: CatalogCategorizable>(
        in items: [Element]
    ) -> [String] {
        CatalogOrganizer.sections(from: items).map(\.category)
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
