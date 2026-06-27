import Foundation
import Testing

@testable import Wardrobe

struct CatalogCompactorTests {

    private struct StubItem: StylableItem {
        let stylableID: UUID
        let name: String
        let category: String
        let brand: String?
        let colors: [String]
        let material: String?

        init(
            id: UUID = UUID(),
            name: String,
            category: String,
            brand: String? = nil,
            colors: [String] = [],
            material: String? = nil
        ) {
            self.stylableID = id
            self.name = name
            self.category = category
            self.brand = brand
            self.colors = colors
            self.material = material
        }
    }

    @Test func mapsIdToUUIDStringAndCarriesAttributes() {
        let id = UUID()
        let out = CatalogCompactor.compact([
            StubItem(
                id: id, name: "Oxford Shirt", category: "top",
                brand: "Everlane", colors: ["white", "blue"], material: "cotton"
            )
        ])
        #expect(out.count == 1)
        let item = out[0]
        #expect(item.id == id.uuidString)
        #expect(item.name == "Oxford Shirt")
        #expect(item.category == "top")
        #expect(item.brand == "Everlane")
        #expect(item.colors == ["white", "blue"])
        #expect(item.material == "cotton")
    }

    @Test func preservesOrderAndOptionalsStayNil() {
        let out = CatalogCompactor.compact([
            StubItem(name: "Tee", category: "top"),
            StubItem(name: "Jeans", category: "bottom"),
        ])
        #expect(out.map(\.name) == ["Tee", "Jeans"])
        #expect(out[0].brand == nil)
        #expect(out[0].material == nil)
        #expect(out[0].colors.isEmpty)
    }

    @Test func emptyCatalogMapsToEmpty() {
        #expect(CatalogCompactor.compact([StubItem]()).isEmpty)
    }
}
