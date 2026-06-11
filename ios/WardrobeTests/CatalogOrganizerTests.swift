import Foundation
import Testing
@testable import Wardrobe

/// Unit tests for the pure catalog grouping/ordering logic. Uses a lightweight
/// stub rather than the SwiftData `Item` so no model container is needed.
struct CatalogOrganizerTests {

    private struct StubItem: CatalogCategorizable {
        let category: String
        let name: String
        var brand: String?
        var purchaseDate: Date?

        init(category: String, name: String, brand: String? = nil, purchaseDate: Date? = nil) {
            self.category = category
            self.name = name
            self.brand = brand
            self.purchaseDate = purchaseDate
        }
    }

    @Test func knownCategoriesSortInCanonicalOrder() {
        let items = [
            StubItem(category: "bag", name: "Tote"),
            StubItem(category: "top", name: "Tee"),
            StubItem(category: "shoe", name: "Loafer"),
            StubItem(category: "dress", name: "Slip"),
        ]
        let order = CatalogOrganizer.sections(from: items).map(\.category)
        #expect(order == ["top", "dress", "shoe", "bag"])
    }

    @Test func unknownCategoriesComeAfterKnownAlphabetically() {
        let items = [
            StubItem(category: "swimwear", name: "Trunks"),
            StubItem(category: "bag", name: "Clutch"),
            StubItem(category: "loungewear", name: "Robe"),
        ]
        let order = CatalogOrganizer.sections(from: items).map(\.category)
        #expect(order == ["bag", "loungewear", "swimwear"])
    }

    @Test func itemsWithinASectionSortByNameCaseInsensitively() {
        let items = [
            StubItem(category: "top", name: "zephyr tee"),
            StubItem(category: "top", name: "Alpha shirt"),
            StubItem(category: "top", name: "beta blouse"),
        ]
        let section = CatalogOrganizer.sections(from: items).first
        #expect(section?.items.map(\.name) == ["Alpha shirt", "beta blouse", "zephyr tee"])
    }

    @Test func categoryIsNormalizedByCaseAndWhitespace() {
        let items = [
            StubItem(category: "  TOP ", name: "A"),
            StubItem(category: "top", name: "B"),
        ]
        let sections = CatalogOrganizer.sections(from: items)
        #expect(sections.count == 1)
        #expect(sections.first?.category == "top")
        #expect(sections.first?.items.count == 2)
    }

    @Test func blankCategoryBecomesUncategorizedAndSortsLast() {
        let items = [
            StubItem(category: "", name: "Mystery"),
            StubItem(category: "top", name: "Tee"),
        ]
        let order = CatalogOrganizer.sections(from: items).map(\.category)
        #expect(order == ["top", "uncategorized"])
    }

    @Test func emptyInputYieldsNoSections() {
        #expect(CatalogOrganizer.sections(from: [StubItem]()).isEmpty)
    }

    @Test func styleTitlesArePluralizedForKnownCategories() {
        #expect(CatalogCategoryStyle.title("top") == "Tops")
        #expect(CatalogCategoryStyle.title("accessory") == "Accessories")
        #expect(CatalogCategoryStyle.title("swimwear") == "Swimwear") // capitalized fallback
    }

    // MARK: - Filtering

    @Test func searchMatchesNameOrBrandCaseInsensitively() {
        let items = [
            StubItem(category: "top", name: "Linen Shirt", brand: "Everlane"),
            StubItem(category: "bag", name: "Tote", brand: "Telfar"),
            StubItem(category: "shoe", name: "Runner", brand: "Nike"),
        ]
        #expect(CatalogFilter.apply(to: items, search: "SHIRT", category: nil).map(\.name) == ["Linen Shirt"])
        #expect(CatalogFilter.apply(to: items, search: "telfar", category: nil).map(\.name) == ["Tote"])
        #expect(CatalogFilter.apply(to: items, search: "  ", category: nil).count == 3) // blank = no-op
    }

    @Test func categoryFilterKeepsOnlyThatCategory() {
        let items = [
            StubItem(category: "top", name: "Tee"),
            StubItem(category: "bag", name: "Tote"),
        ]
        #expect(CatalogFilter.apply(to: items, search: "", category: "bag").map(\.name) == ["Tote"])
    }

    @Test func searchAndCategoryCombine() {
        let items = [
            StubItem(category: "top", name: "Wool Tee", brand: "Acme"),
            StubItem(category: "top", name: "Cotton Tee", brand: "Acme"),
            StubItem(category: "bag", name: "Wool Bag", brand: "Acme"),
        ]
        let result = CatalogFilter.apply(to: items, search: "wool", category: "top")
        #expect(result.map(\.name) == ["Wool Tee"])
    }

    @Test func availableCategoriesAreInCanonicalOrder() {
        let items = [
            StubItem(category: "bag", name: "Tote"),
            StubItem(category: "top", name: "Tee"),
            StubItem(category: "swimwear", name: "Trunks"),
        ]
        #expect(CatalogFilter.availableCategories(in: items) == ["top", "bag", "swimwear"])
    }

    // MARK: - Sorting

    @Test func sortByRecentPutsNewestFirstThenUndated() {
        let items = [
            StubItem(category: "top", name: "Old", purchaseDate: Date(timeIntervalSince1970: 1_000)),
            StubItem(category: "top", name: "New", purchaseDate: Date(timeIntervalSince1970: 9_000)),
            StubItem(category: "top", name: "Undated", purchaseDate: nil),
        ]
        let section = CatalogOrganizer.sections(from: items, sortedBy: .recent).first
        #expect(section?.items.map(\.name) == ["New", "Old", "Undated"])
    }

    @Test func sortByBrandPutsBrandedFirstAlphabeticallyThenBrandless() {
        let items = [
            StubItem(category: "top", name: "Z-item", brand: nil),
            StubItem(category: "top", name: "A-item", brand: "Zara"),
            StubItem(category: "top", name: "B-item", brand: "Acme"),
        ]
        let section = CatalogOrganizer.sections(from: items, sortedBy: .brand).first
        // Acme then Zara (branded, by brand A–Z), brandless last.
        #expect(section?.items.map(\.name) == ["B-item", "A-item", "Z-item"])
    }
}
