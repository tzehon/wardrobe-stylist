import Foundation
import Testing

@testable import Wardrobe

private struct CatalogStub: CatalogCategorizable {
    let category: String
    let name: String
    var brand: String?
    var purchaseDate: Date?
    var isFavorite = false
    var isArchived = false
}

struct CatalogOrganizerTests {
    @Test func groupsCanonicalCategoriesAndSortsNames() {
        let items = [
            CatalogStub(category: "shoe", name: "Zulu"),
            CatalogStub(category: "top", name: "Beta"),
            CatalogStub(category: "top", name: "Alpha"),
        ]
        let sections = CatalogOrganizer.sections(from: items, sortedBy: .name)
        #expect(sections.map(\.category) == ["top", "shoe"])
        #expect(sections[0].items.map(\.name) == ["Alpha", "Beta"])
    }

    @Test func filtersActiveFavoritesAndArchive() {
        let active = CatalogStub(category: "top", name: "Active")
        let favorite = CatalogStub(category: "bag", name: "Favorite", isFavorite: true)
        let archived = CatalogStub(category: "shoe", name: "Archived", isArchived: true)
        let items = [active, favorite, archived]

        #expect(CatalogFilter.apply(
            to: items, search: "", category: nil, status: .active
        ).count == 2)
        #expect(CatalogFilter.apply(
            to: items, search: "", category: nil, status: .favorites
        ).map(\.name) == ["Favorite"])
        #expect(CatalogFilter.apply(
            to: items, search: "", category: nil, status: .archived
        ).map(\.name) == ["Archived"])
    }
}
