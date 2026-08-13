import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct ItemEditDraftTests {
    private struct Fixture {
        let container: ModelContainer
        let item: Item
    }

    @Test func initializesFromEveryEditableItemField() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let fixture = try makeFixture(purchaseDate: date)

        let draft = ItemEditDraft(item: fixture.item)

        #expect(draft.name == "Linen shirt")
        #expect(draft.category == "top")
        #expect(draft.subcategory == "button-down")
        #expect(draft.brand == "Atelier")
        #expect(draft.colors == "navy, white")
        #expect(draft.material == "linen")
        #expect(draft.styleNotes == "Relaxed")
        #expect(draft.includesPurchaseDate)
        #expect(draft.purchaseDate == date)
    }

    @Test func inputTrimsTextParsesColorsAndCanRemoveDate() throws {
        let fixture = try makeFixture(purchaseDate: .now)
        var draft = ItemEditDraft(item: fixture.item)
        draft.name = "  Updated shirt  "
        draft.category = " Outerwear "
        draft.subcategory = "  "
        draft.brand = " Studio "
        draft.colors = " navy, , white "
        draft.material = " cotton "
        draft.styleNotes = "  "
        draft.includesPurchaseDate = false

        let input = draft.updateInput

        #expect(input.name == "Updated shirt")
        #expect(input.category == "outerwear")
        #expect(input.subcategory == nil)
        #expect(input.brand == "Studio")
        #expect(input.colors == ["navy", "white"])
        #expect(input.material == "cotton")
        #expect(input.styleNotes == nil)
        #expect(input.purchaseDate == nil)
    }

    @Test func requiresBothNameAndCategory() throws {
        let fixture = try makeFixture()
        var draft = ItemEditDraft(item: fixture.item)
        #expect(draft.canSave)

        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "Shirt"
        draft.category = "\n"
        #expect(!draft.canSave)
    }

    private func makeFixture(purchaseDate: Date? = nil) throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        let item = Item(
            name: "Linen shirt",
            category: "top",
            subcategory: "button-down",
            brand: "Atelier",
            colors: ["navy", "white"],
            material: "linen",
            styleNotes: "Relaxed",
            source: .email,
            purchaseDate: purchaseDate
        )
        container.mainContext.insert(item)
        try container.mainContext.save()
        return Fixture(container: container, item: item)
    }
}
