import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct WardrobeStoreTests {
    private enum FixtureError: Error {
        case saveFailed
    }

    private struct Fixture {
        // SwiftData's context does not retain its container. Keep both alive for
        // the full test or any insert traps in the framework.
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        context.autosaveEnabled = false
        return Fixture(container: container, context: context)
    }

    private func failingStore(_ context: ModelContext) -> WardrobeStore {
        WardrobeStore(modelContext: context) { _ in
            throw FixtureError.saveFailed
        }
    }

    private func seedItem(
        in context: ModelContext,
        id: UUID = UUID(),
        name: String = "Navy shirt",
        category: String = "top"
    ) throws -> Item {
        let item = Item(id: id, name: name, category: category, source: .manual)
        context.insert(item)
        try context.save()
        return item
    }

    private func itemInput(
        name: String = "Navy shirt",
        category: String = "top"
    ) -> ManualItemInput {
        ManualItemInput(
            name: name,
            category: category,
            brand: nil,
            colors: [],
            material: nil,
            source: .photo,
            imageData: nil,
            thumbnailData: nil
        )
    }

    @Test func addCommitsBeforeReportingSuccess() throws {
        let fixture = try makeFixture()
        let context = fixture.context

        let item = try WardrobeStore(modelContext: context).addItem(itemInput())

        let fetched = try context.fetch(FetchDescriptor<Item>())
        #expect(fetched.map(\.id) == [item.id])
        #expect(!context.hasChanges)
    }

    @Test func failedAddRollsBackTheInsertedItem() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let input = itemInput()

        let error = try capturePersistenceError {
            try failingStore(context).addItem(input)
        }

        let verification = ModelContext(fixture.container)
        #expect(error.operation == .addItem)
        #expect(error.diagnostic.contains("saveFailed"))
        #expect(!error.message.contains(error.diagnostic))
        #expect(try verification.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(!context.hasChanges)

        let retried = try WardrobeStore(modelContext: context).addItem(input)
        #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.id) == [retried.id])
    }

    @Test func deleteCommitsTheRemoval() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let item = try seedItem(in: context)

        try WardrobeStore(modelContext: context).deleteItem(item)

        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func failedDeleteRollsBackAndKeepsTheItem() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let item = try seedItem(in: context)

        let error = try capturePersistenceError {
            try failingStore(context).deleteItem(item)
        }

        let verification = ModelContext(fixture.container)
        let fetched = try verification.fetch(FetchDescriptor<Item>())
        #expect(error.operation == .deleteItem)
        #expect(fetched.map(\.id) == [item.id])
        #expect(fetched.first?.name == "Navy shirt")
        #expect(!context.hasChanges)
    }

    @Test func deleteRejectsAnItemFromAnotherContextBeforeSaving() throws {
        let destination = try makeFixture()
        let source = try makeFixture()
        let foreignItem = try seedItem(in: source.context)
        var saveCalls = 0
        let store = WardrobeStore(modelContext: destination.context) { _ in saveCalls += 1 }

        let error = try capturePersistenceError {
            try store.deleteItem(foreignItem)
        }

        #expect(error.operation == .deleteItem)
        #expect(error.diagnostic.contains("itemFromDifferentStore"))
        #expect(saveCalls == 0)
        #expect(try source.context.fetch(FetchDescriptor<Item>()).map(\.id) == [foreignItem.id])
        #expect(try destination.context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func recordWearCommitsOutfitAndOneLogPerItem() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let shirt = try seedItem(in: context, name: "Navy shirt", category: "top")
        let trousers = try seedItem(in: context, name: "Grey trousers", category: "bottom")
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let outfit = try WardrobeStore(modelContext: context).recordWear(
            items: [shirt, trousers],
            occasion: "work",
            rationale: "Balanced layers",
            colorStory: "Navy and grey",
            date: date
        )

        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        let wearLogs = try context.fetch(FetchDescriptor<WearLog>())
        #expect(outfits.map(\.id) == [outfit.id])
        #expect(outfits.first?.createdAt == date)
        #expect(Set(outfits.first?.items.map(\.id) ?? []) == [shirt.id, trousers.id])
        #expect(wearLogs.count == 2)
        #expect(wearLogs.allSatisfy { $0.date == date && $0.outfit?.id == outfit.id })
        #expect(Set(wearLogs.compactMap { $0.item?.id }) == [shirt.id, trousers.id])
        #expect(!context.hasChanges)
    }

    @Test func failedWearRollsBackOutfitAndEveryWearLog() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let shirt = try seedItem(in: context, name: "Navy shirt", category: "top")
        let trousers = try seedItem(in: context, name: "Grey trousers", category: "bottom")

        let error = try capturePersistenceError {
            try failingStore(context).recordWear(
                items: [shirt, trousers],
                occasion: "work",
                rationale: "Balanced layers",
                colorStory: "Navy and grey",
                date: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        let verification = ModelContext(fixture.container)
        #expect(error.operation == .recordWear)
        #expect(try verification.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<WearLog>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<Item>()).count == 2)
        #expect(!context.hasChanges)
    }

    @Test func recordWearDeduplicatesItemsBeforeCreatingLogs() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let shirt = try seedItem(in: context)

        let outfit = try WardrobeStore(modelContext: context).recordWear(
            items: [shirt, shirt],
            occasion: "work",
            rationale: nil,
            colorStory: nil,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(outfit.items.map(\.id) == [shirt.id])
        #expect(try context.fetch(FetchDescriptor<WearLog>()).count == 1)
    }

    @Test func recordWearRejectsAnItemFromAnotherContextBeforeSaving() throws {
        let destination = try makeFixture()
        let source = try makeFixture()
        let foreignItem = try seedItem(in: source.context)
        var saveCalls = 0
        let store = WardrobeStore(modelContext: destination.context) { _ in saveCalls += 1 }

        let error = try capturePersistenceError {
            try store.recordWear(
                items: [foreignItem],
                occasion: nil,
                rationale: nil,
                colorStory: nil,
                date: .now
            )
        }

        #expect(error.operation == .recordWear)
        #expect(error.diagnostic.contains("itemFromDifferentStore"))
        #expect(saveCalls == 0)
        #expect(try destination.context.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try destination.context.fetch(FetchDescriptor<WearLog>()).isEmpty)
    }

    @Test func dirtyContextFailsBeforeTheActionAndDoesNotCommitOrRollbackItsBaseline() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let baseline = Item(name: "Unsaved baseline", category: "top", source: .manual)
        context.insert(baseline)
        var saveCalls = 0
        let store = WardrobeStore(modelContext: context) { _ in
            saveCalls += 1
        }

        let error = try capturePersistenceError {
            try store.addItem(itemInput(name: "Failed action", category: "bottom"))
        }

        #expect(error.operation == .addItem)
        #expect(error.diagnostic.contains("pendingChanges"))
        #expect(saveCalls == 0)
        #expect(context.insertedModelsArray.compactMap { $0 as? Item }.map(\.id) == [baseline.id])
        #expect(context.hasChanges)
    }

    @Test func coordinatorRunsDismissalOnlyAfterACommittedRetry() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let coordinator = WardrobeWriteCoordinator()
        var didDismiss = false

        coordinator.perform(
            operation: .addItem,
            write: {
                try failingStore(context).addItem(itemInput())
            },
            onSuccess: { didDismiss = true }
        )

        #expect(!didDismiss)
        #expect(coordinator.error?.operation == .addItem)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)

        coordinator.perform(
            operation: .addItem,
            write: {
                try WardrobeStore(modelContext: context).addItem(itemInput())
            },
            onSuccess: { didDismiss = true }
        )

        #expect(didDismiss)
        #expect(coordinator.error == nil)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    private func capturePersistenceError(
        _ operation: () throws -> Void
    ) throws -> WardrobePersistenceError {
        do {
            try operation()
            Issue.record("Expected the transaction to fail")
            throw FixtureError.saveFailed
        } catch let error as WardrobePersistenceError {
            return error
        }
    }
}
