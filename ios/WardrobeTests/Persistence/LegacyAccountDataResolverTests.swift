import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct LegacyAccountDataResolverTests {
    private enum FixtureError: Error { case saveFailed }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
    }

    private func fixture() throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        container.mainContext.autosaveEnabled = false
        return Fixture(container: container, context: container.mainContext)
    }

    private func seedLegacyAndScopedRows(in context: ModelContext) throws -> (
        manual: Item,
        legacy: Item,
        scoped: Item,
        scopedOutfit: Outfit
    ) {
        let otherScope = WardrobeAccountScope.external(.external("other"))
        let manual = Item(name: "Manual", category: "top", source: .manual)
        let legacy = Item(name: "Legacy import", category: "bag", source: .email)
        let scoped = Item(
            name: "Other import",
            category: "shoe",
            source: .email,
            accountSubjectKey: otherScope.rawValue
        )
        let legacyOutfit = Outfit(items: [manual, legacy])
        let scopedOutfit = Outfit(accountSubjectKey: otherScope.rawValue, items: [manual, scoped])
        context.insert(manual)
        context.insert(legacy)
        context.insert(scoped)
        context.insert(legacyOutfit)
        context.insert(scopedOutfit)
        context.insert(WearLog(item: legacy, outfit: legacyOutfit))
        context.insert(WearLog(
            item: scoped,
            outfit: scopedOutfit,
            accountSubjectKey: otherScope.rawValue
        ))
        try context.save()
        return (manual, legacy, scoped, scopedOutfit)
    }

    @Test func summaryCountsOnlyAmbiguousPreAccountRows() throws {
        let fixture = try fixture()
        _ = try seedLegacyAndScopedRows(in: fixture.context)

        let summary = try LegacyAccountDataResolver(modelContext: fixture.context).summary()

        #expect(summary == LegacyAccountDataSummary(importedItems: 1, outfits: 1, wearLogs: 1))
    }

    @Test func keepExplicitlyAssignsOnlyLegacyAccountData() throws {
        let fixture = try fixture()
        let rows = try seedLegacyAndScopedRows(in: fixture.context)
        let subject = PrivacySubjectID.external("chosen-account")
        let chosenScope = WardrobeAccountScope.external(subject)

        try LegacyAccountDataResolver(modelContext: fixture.context)
            .keepWithAccount(subjectID: subject)

        let items = try fixture.context.fetch(FetchDescriptor<Item>())
        let outfits = try fixture.context.fetch(FetchDescriptor<Outfit>())
        let wears = try fixture.context.fetch(FetchDescriptor<WearLog>())
        #expect(items.first(where: { $0.id == rows.manual.id })?.accountSubjectKey == nil)
        #expect(items.first(where: { $0.id == rows.legacy.id })?.accountSubjectKey == chosenScope.rawValue)
        #expect(items.first(where: { $0.id == rows.scoped.id })?.accountSubjectKey
            == WardrobeAccountScope.external(.external("other")).rawValue)
        #expect(outfits.filter { $0.accountSubjectKey == chosenScope.rawValue }.count == 1)
        #expect(wears.filter { $0.accountSubjectKey == chosenScope.rawValue }.count == 1)
        #expect(try LegacyAccountDataResolver(modelContext: fixture.context).summary().isEmpty)
    }

    @Test func deleteRemovesOnlyLegacyImportsAndHistory() throws {
        let fixture = try fixture()
        let rows = try seedLegacyAndScopedRows(in: fixture.context)

        try LegacyAccountDataResolver(modelContext: fixture.context).deleteLegacyAccountData()

        let items = try fixture.context.fetch(FetchDescriptor<Item>())
        let outfits = try fixture.context.fetch(FetchDescriptor<Outfit>())
        let wears = try fixture.context.fetch(FetchDescriptor<WearLog>())
        #expect(Set(items.map(\.id)) == [rows.manual.id, rows.scoped.id])
        #expect(outfits.map(\.id) == [rows.scopedOutfit.id])
        #expect(wears.count == 1)
        #expect(wears.first?.accountSubjectKey
            == WardrobeAccountScope.external(.external("other")).rawValue)
    }

    @Test func failedResolutionRollsBackEveryAssignment() throws {
        let fixture = try fixture()
        let rows = try seedLegacyAndScopedRows(in: fixture.context)
        let resolver = LegacyAccountDataResolver(
            modelContext: fixture.context,
            save: { _ in throw FixtureError.saveFailed }
        )

        #expect(throws: LegacyAccountDataError.self) {
            try resolver.keepWithAccount(subjectID: .external("chosen"))
        }

        let verification = ModelContext(fixture.container)
        let legacy = try #require(verification.fetch(FetchDescriptor<Item>())
            .first(where: { $0.id == rows.legacy.id }))
        #expect(legacy.accountSubjectKey == nil)
        #expect(try LegacyAccountDataResolver(modelContext: verification).summary()
            == LegacyAccountDataSummary(importedItems: 1, outfits: 1, wearLogs: 1))
        #expect(!fixture.context.hasChanges)
    }
}
