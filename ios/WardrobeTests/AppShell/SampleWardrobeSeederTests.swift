import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct SampleWardrobeSeederTests {
    private struct Fixture {
        // A ModelContext does not retain its ModelContainer. Keep both alive for
        // the full test to avoid a SwiftData framework trap during inserts.
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        context.autosaveEnabled = false
        return Fixture(container: container, context: context)
    }

    @Test func manifestUsesTheFixedShippedIdentifiers() {
        let expected = Set([
            UUID(uuidString: "5A4D504C-4501-4000-8000-000000000001")!,
            UUID(uuidString: "5A4D504C-4501-4000-8000-000000000002")!,
            UUID(uuidString: "5A4D504C-4501-4000-8000-000000000003")!,
            UUID(uuidString: "5A4D504C-4501-4000-8000-000000000004")!,
        ])

        #expect(SampleWardrobeSeeder.sampleIDs == expected)
        #expect(SampleWardrobeSeeder.samples.count == expected.count)
        #expect(Set(SampleWardrobeSeeder.samples.map(\.category)) == [
            "top", "bottom", "shoe", "outerwear",
        ])
    }

    @Test func seedIsIdempotentAndDoesNotOverwriteAnExistingSample() throws {
        let fixture = try makeFixture()
        let seeder = SampleWardrobeSeeder(modelContext: fixture.context)

        #expect(try seeder.seed() == SampleWardrobeSeeder.samples.count)
        #expect(try seeder.seed() == 0)

        let items = try fixture.context.fetch(FetchDescriptor<Item>())
        #expect(Set(items.map(\.id)) == SampleWardrobeSeeder.sampleIDs)
        #expect(items.allSatisfy { $0.source == .manual })

        let edited = try #require(items.first)
        edited.name = "My edited sample"
        try fixture.context.save()

        #expect(try seeder.seed() == 0)
        let refetched = try fixture.context.fetch(FetchDescriptor<Item>())
        #expect(refetched.first(where: { $0.id == edited.id })?.name == "My edited sample")
    }

    @Test func seedRepairsOnlyAMissingManifestItem() throws {
        let fixture = try makeFixture()
        let seeder = SampleWardrobeSeeder(modelContext: fixture.context)
        try seeder.seed()
        let removedID = SampleWardrobeSeeder.samples[1].id
        let removed = try #require(
            fixture.context.fetch(FetchDescriptor<Item>()).first(where: { $0.id == removedID })
        )
        fixture.context.delete(removed)
        try fixture.context.save()

        #expect(try seeder.seed() == 1)
        #expect(Set(try fixture.context.fetch(FetchDescriptor<Item>()).map(\.id)) == SampleWardrobeSeeder.sampleIDs)
    }

    @Test func removalTargetsSamplesAndPreservesUserDataAndRelationships() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let seeder = SampleWardrobeSeeder(modelContext: context)
        try seeder.seed()

        let userItem = Item(
            id: UUID(uuidString: "AB12CD34-EF56-4789-AB12-CD34EF567890")!,
            name: "My linen shirt",
            category: "top",
            source: .photo
        )
        let userOutfit = Outfit(occasion: "Weekend", items: [userItem])
        let userWear = WearLog(item: userItem, outfit: userOutfit, feedback: 5)
        context.insert(userItem)
        context.insert(userOutfit)
        context.insert(userWear)
        try context.save()

        #expect(try seeder.remove() == SampleWardrobeSeeder.samples.count)

        let verification = ModelContext(fixture.container)
        let items = try verification.fetch(FetchDescriptor<Item>())
        let outfits = try verification.fetch(FetchDescriptor<Outfit>())
        let wearLogs = try verification.fetch(FetchDescriptor<WearLog>())
        #expect(items.map(\.id) == [userItem.id])
        #expect(outfits.map(\.id) == [userOutfit.id])
        #expect(wearLogs.map(\.id) == [userWear.id])
        #expect(wearLogs.first?.item?.id == userItem.id)
        #expect(wearLogs.first?.outfit?.id == userOutfit.id)
        #expect(try seeder.remove() == 0)
    }

    @Test func dirtyContextFailsBeforeMutatingTheUsersPendingWork() throws {
        let fixture = try makeFixture()
        let pending = Item(name: "Unsaved personal item", category: "top", source: .manual)
        fixture.context.insert(pending)

        do {
            try SampleWardrobeSeeder(modelContext: fixture.context).seed()
            Issue.record("Expected seeding to reject a dirty context")
        } catch let error as SampleWardrobeError {
            #expect(error.diagnostic.contains("pendingChanges"))
        }

        #expect(fixture.context.hasChanges)
        #expect(fixture.context.insertedModelsArray.compactMap { $0 as? Item }.map(\.id) == [pending.id])
    }
}
