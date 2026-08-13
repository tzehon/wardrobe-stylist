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
}
