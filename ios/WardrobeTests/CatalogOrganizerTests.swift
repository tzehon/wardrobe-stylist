import Testing
@testable import Wardrobe

/// Unit tests for the pure catalog grouping/ordering logic. Uses a lightweight
/// stub rather than the SwiftData `Item` so no model container is needed.
struct CatalogOrganizerTests {

    private struct StubItem: CatalogCategorizable {
        let category: String
        let name: String
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
}
