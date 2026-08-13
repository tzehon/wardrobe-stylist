import Foundation
import Testing

@testable import Wardrobe

struct ItemDraftTests {

    @Test func canSaveNamedItemWithoutImage() {
        var draft = ItemDraft()
        draft.name = "Linen Tee"
        draft.hasImage = false
        #expect(draft.canSave)
    }

    @Test func cannotSaveWithBlankName() {
        var draft = ItemDraft()
        draft.hasImage = true
        draft.name = "   "
        #expect(draft.canSave == false)
    }

    @Test func canSaveWithImageAndName() {
        var draft = ItemDraft()
        draft.hasImage = true
        draft.name = "Linen Tee"
        #expect(draft.canSave)
    }

    @Test func parsesTrimsAndDropsEmptyColors() {
        #expect(ItemDraft.parseColors(" navy ,white,, Red ") == ["navy", "white", "Red"])
        #expect(ItemDraft.parseColors("") == [])
        #expect(ItemDraft.parseColors("  ") == [])
    }

    @Test func validatesAndNormalizesPurchaseMetadata() {
        var draft = ItemDraft()
        draft.name = "Tailored trouser"
        draft.purchasePrice = " 129.50 "
        draft.purchaseCurrency = " sgd "
        #expect(draft.canSave)
        #expect(draft.parsedPrice == 129.5)
        #expect(draft.normalizedCurrency == "SGD")

        draft.purchasePrice = "-1"
        #expect(!draft.canSave)
        draft.purchasePrice = "12"
        draft.purchaseCurrency = "dollars"
        #expect(!draft.canSave)
    }

    @Test func manualInputIncludesEverySharedFormField() {
        let purchased = Date(timeIntervalSince1970: 1_700_000_000)
        var draft = ItemDraft()
        draft.name = "  Linen shirt "
        draft.category = " TOP "
        draft.subcategory = " button-down "
        draft.brand = " Atelier "
        draft.colors = "navy, white"
        draft.size = " M "
        draft.material = " linen "
        draft.styleNotes = " relaxed "
        draft.includesPurchaseDate = true
        draft.purchaseDate = purchased
        draft.purchasePrice = "88"
        draft.purchaseCurrency = "usd"

        let input = draft.manualInput(source: .manual, imageData: nil, thumbnailData: nil)
        #expect(input.name == "Linen shirt")
        #expect(input.category == "top")
        #expect(input.subcategory == "button-down")
        #expect(input.brand == "Atelier")
        #expect(input.colors == ["navy", "white"])
        #expect(input.size == "M")
        #expect(input.material == "linen")
        #expect(input.styleNotes == "relaxed")
        #expect(input.purchaseDate == purchased)
        #expect(input.purchasePrice == 88)
        #expect(input.purchaseCurrency == "USD")
    }
}
