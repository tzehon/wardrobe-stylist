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

    @Test func stylingFieldsUseTheBackendCodePointBoundaries() {
        var draft = ItemDraft()
        draft.name = String(repeating: "n", count: RecommendContractLimits.maximumNameLength)
        draft.category = String(
            repeating: "c",
            count: RecommendContractLimits.maximumCategoryLength
        )
        draft.brand = String(repeating: "b", count: RecommendContractLimits.maximumBrandLength)
        draft.material = String(
            repeating: "m",
            count: RecommendContractLimits.maximumMaterialLength
        )
        draft.colors = Array(
            repeating: "navy",
            count: RecommendContractLimits.maximumColors
        ).joined(separator: ",")
        #expect(draft.canSave)
        #expect(draft.identityValidationMessage == nil)
        #expect(draft.detailsValidationMessage == nil)

        draft.name += "n"
        #expect(!draft.canSave)
        #expect(draft.identityValidationMessage == "Use 256 or fewer characters for the name.")
        draft.name.removeLast()

        draft.category += "c"
        #expect(!draft.canSave)
        #expect(draft.identityValidationMessage == "Use 64 or fewer characters for the category.")
        draft.category.removeLast()

        draft.brand += "b"
        #expect(!draft.canSave)
        #expect(draft.identityValidationMessage == "Use 128 or fewer characters for the brand.")
        draft.brand.removeLast()

        draft.material += "m"
        #expect(!draft.canSave)
        #expect(draft.detailsValidationMessage == "Use 128 or fewer characters for the material.")
        draft.material.removeLast()

        draft.colors += ",white"
        #expect(!draft.canSave)
        #expect(draft.detailsValidationMessage == "List no more than 16 colors.")
    }

    @Test func fieldLimitsCountUnicodeCodePointsLikeTheBackend() {
        var draft = ItemDraft()
        draft.name = String(repeating: "👨‍👩‍👧‍👦", count: 40)

        #expect(draft.name.count == 40)
        #expect(draft.name.unicodeScalars.count > RecommendContractLimits.maximumNameLength)
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
