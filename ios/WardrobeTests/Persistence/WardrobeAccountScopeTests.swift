import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct WardrobeAccountScopeTests {
    private let accountA = PrivacySubjectID.external("stable-account-a")
    private let accountB = PrivacySubjectID.external("stable-account-b")

    @Test func externalScopeIsStableOpaqueAndProviderNeutral() {
        let first = WardrobeAccountScope.external(accountA)
        let again = WardrobeAccountScope.external(accountA)
        let other = WardrobeAccountScope.external(accountB)

        #expect(first == again)
        #expect(first != other)
        #expect(first.rawValue.hasPrefix("external:v1:"))
        #expect(!first.rawValue.contains("stable-account-a"))
        #expect(WardrobeAccountScope(activeExternalSubject: nil) == .deviceLocal)
        #expect(WardrobeAccountScope(activeExternalSubject: accountA) == first)
        #expect(accountA.isExternal)
        #expect(!PrivacySubjectID.deviceLocal.isExternal)
    }

    @Test func localItemsAreSharedButImportedItemsAreAccountIsolated() {
        let scopeA = WardrobeAccountScope.external(accountA)
        let scopeB = WardrobeAccountScope.external(accountB)
        let manual = Item(name: "Manual", category: "top", source: .manual)
        let photo = Item(name: "Photo", category: "shoe", source: .photo)
        let importedA = Item(
            name: "A import",
            category: "bag",
            source: .email,
            accountSubjectKey: scopeA.rawValue
        )
        let importedB = Item(
            name: "B import",
            category: "dress",
            source: .email,
            accountSubjectKey: scopeB.rawValue
        )
        let legacy = Item(name: "Legacy", category: "top", source: .email)
        let all = [manual, photo, importedA, importedB, legacy]

        #expect(WardrobeAccountFilter.visibleItems(from: all, in: .deviceLocal).map(\.name)
            == ["Manual", "Photo"])
        #expect(WardrobeAccountFilter.visibleItems(from: all, in: scopeA).map(\.name)
            == ["Manual", "Photo", "A import"])
        #expect(WardrobeAccountFilter.visibleItems(from: all, in: scopeB).map(\.name)
            == ["Manual", "Photo", "B import"])
    }

    @Test func outfitAndWearHistoryNeverCrossScopesAndLegacyRowsStayHidden() {
        let scopeA = WardrobeAccountScope.external(accountA)
        let scopeB = WardrobeAccountScope.external(accountB)
        let item = Item(name: "Shared", category: "top", source: .manual)
        let outfitA = Outfit(accountSubjectKey: scopeA.rawValue, items: [item])
        let outfitB = Outfit(accountSubjectKey: scopeB.rawValue, items: [item])
        let legacyOutfit = Outfit(items: [item])
        let wearA = WearLog(item: item, outfit: outfitA, accountSubjectKey: scopeA.rawValue)
        let wearB = WearLog(item: item, outfit: outfitB, accountSubjectKey: scopeB.rawValue)
        let legacyWear = WearLog(item: item, outfit: legacyOutfit)

        #expect(WardrobeAccountFilter.visibleOutfits(
            from: [outfitA, outfitB, legacyOutfit], in: scopeA
        ).map(\.id) == [outfitA.id])
        #expect(WardrobeAccountFilter.visibleWearLogs(
            from: [wearA, wearB, legacyWear], in: scopeA
        ).map(\.id) == [wearA.id])
        #expect(WardrobeAccountFilter.visibleOutfits(
            from: [outfitA, outfitB, legacyOutfit], in: .deviceLocal
        ).isEmpty)
        #expect(WardrobeAccountFilter.visibleWearLogs(
            from: [wearA, wearB, legacyWear], in: .deviceLocal
        ).isEmpty)
    }
}
