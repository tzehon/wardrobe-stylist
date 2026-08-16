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
            subcategory: nil,
            brand: nil,
            colors: [],
            material: nil,
            styleNotes: nil,
            size: nil,
            purchaseDate: nil,
            purchasePrice: nil,
            purchaseCurrency: nil,
            source: .photo,
            imageData: nil,
            thumbnailData: nil
        )
    }

    private func updateInput(
        name: String = "Updated linen shirt",
        category: String = "outerwear"
    ) -> ItemUpdateInput {
        ItemUpdateInput(
            name: name,
            category: category,
            subcategory: "overshirt",
            brand: "Atelier",
            colors: ["navy", "white"],
            material: "linen",
            styleNotes: "Relaxed fit",
            size: "M",
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            purchasePrice: 129.5,
            purchaseCurrency: "SGD",
            imageUpdate: .unchanged,
            acceptPendingReview: false
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

    @Test func updateCommitsEveryEditableField() throws {
        let fixture = try makeFixture()
        let item = try seedItem(in: fixture.context)
        let input = updateInput()

        try WardrobeStore(modelContext: fixture.context).updateItem(item, with: input)

        let fetched = try #require(fixture.context.fetch(FetchDescriptor<Item>()).first)
        #expect(fetched.name == input.name)
        #expect(fetched.category == input.category)
        #expect(fetched.subcategory == input.subcategory)
        #expect(fetched.brand == input.brand)
        #expect(fetched.colors == input.colors)
        #expect(fetched.material == input.material)
        #expect(fetched.styleNotes == input.styleNotes)
        #expect(fetched.size == input.size)
        #expect(fetched.purchaseDate == input.purchaseDate)
        #expect(fetched.purchasePrice == input.purchasePrice)
        #expect(fetched.purchaseCurrency == input.purchaseCurrency)
        #expect(!fixture.context.hasChanges)
    }

    @Test func failedUpdateRollsBackEveryField() throws {
        let fixture = try makeFixture()
        let item = try seedItem(in: fixture.context)

        let error = try capturePersistenceError {
            try failingStore(fixture.context).updateItem(item, with: updateInput())
        }

        let verification = ModelContext(fixture.container)
        let fetched = try #require(verification.fetch(FetchDescriptor<Item>()).first)
        #expect(error.operation == .updateItem)
        #expect(fetched.name == "Navy shirt")
        #expect(fetched.category == "top")
        #expect(fetched.subcategory == nil)
        #expect(fetched.brand == nil)
        #expect(fetched.colors.isEmpty)
        #expect(fetched.material == nil)
        #expect(fetched.styleNotes == nil)
        #expect(fetched.size == nil)
        #expect(fetched.purchaseDate == nil)
        #expect(fetched.purchasePrice == nil)
        #expect(fetched.purchaseCurrency == nil)
        #expect(!fixture.context.hasChanges)
    }

    @Test func updateRejectsAnItemFromAnotherContextBeforeSaving() throws {
        let destination = try makeFixture()
        let source = try makeFixture()
        let foreignItem = try seedItem(in: source.context)
        var saveCalls = 0
        let store = WardrobeStore(modelContext: destination.context) { _ in saveCalls += 1 }

        let error = try capturePersistenceError {
            try store.updateItem(foreignItem, with: updateInput())
        }

        #expect(error.operation == .updateItem)
        #expect(error.diagnostic.contains("itemFromDifferentStore"))
        #expect(saveCalls == 0)
        #expect(foreignItem.name == "Navy shirt")
    }

    @Test func pendingImportCanBeCorrectedAndAcceptedAtomically() throws {
        let fixture = try makeFixture()
        let item = Item(
            name: "Extracted shirt",
            category: "top",
            source: .email,
            accountSubjectKey: WardrobeAccountScope.deviceLocal.rawValue,
            extractionConfidence: .low,
            reviewState: .pendingReview
        )
        fixture.context.insert(item)
        try fixture.context.save()
        let reviewedAtFloor = Date.now
        var input = updateInput()
        input = ItemUpdateInput(
            name: input.name,
            category: input.category,
            subcategory: input.subcategory,
            brand: input.brand,
            colors: input.colors,
            material: input.material,
            styleNotes: input.styleNotes,
            size: input.size,
            purchaseDate: input.purchaseDate,
            purchasePrice: input.purchasePrice,
            purchaseCurrency: input.purchaseCurrency,
            imageUpdate: .unchanged,
            acceptPendingReview: true
        )

        try WardrobeStore(modelContext: fixture.context).updateItem(item, with: input)

        #expect(item.reviewState == .accepted)
        #expect(try #require(item.reviewedAt) >= reviewedAtFloor)
        #expect(item.extractionConfidence == .low)
    }

    @Test func updatePreservesReplacesAndExplicitlyRemovesImages() throws {
        let fixture = try makeFixture()
        let originalImage = Data([0x01])
        let originalThumbnail = Data([0x02])
        let item = Item(
            name: "Image item",
            category: "top",
            imageURL: "https://example.com/original.jpg",
            imageData: originalImage,
            thumbnailData: originalThumbnail,
            featurePrint: Data([0x03])
        )
        fixture.context.insert(item)
        try fixture.context.save()

        try WardrobeStore(modelContext: fixture.context).updateItem(item, with: updateInput())
        #expect(item.imageData == originalImage)
        #expect(item.thumbnailData == originalThumbnail)
        #expect(item.imageURL == "https://example.com/original.jpg")
        #expect(item.featurePrint == Data([0x03]))

        let replacement = ItemUpdateInput(
            name: item.name,
            category: item.category,
            subcategory: nil,
            brand: nil,
            colors: [],
            material: nil,
            styleNotes: nil,
            size: nil,
            purchaseDate: nil,
            purchasePrice: nil,
            purchaseCurrency: nil,
            imageUpdate: .replace(imageData: Data([0x10]), thumbnailData: Data([0x11])),
            acceptPendingReview: false
        )
        try WardrobeStore(modelContext: fixture.context).updateItem(item, with: replacement)
        #expect(item.imageData == Data([0x10]))
        #expect(item.thumbnailData == Data([0x11]))
        #expect(item.imageURL == nil)
        #expect(item.featurePrint == nil)

        let removal = ItemUpdateInput(
            name: item.name,
            category: item.category,
            subcategory: nil,
            brand: nil,
            colors: [],
            material: nil,
            styleNotes: nil,
            size: nil,
            purchaseDate: nil,
            purchasePrice: nil,
            purchaseCurrency: nil,
            imageUpdate: .remove,
            acceptPendingReview: false
        )
        try WardrobeStore(modelContext: fixture.context).updateItem(item, with: removal)
        #expect(item.imageData == nil)
        #expect(item.thumbnailData == nil)
        #expect(item.imageURL == nil)
    }

    @Test func bulkAcceptanceOnlyTouchesVisiblePendingItems() throws {
        let fixture = try makeFixture()
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let pendingA = Item(name: "A", category: "top", reviewState: .pendingReview)
        let pendingB = Item(name: "B", category: "bag", reviewState: .pendingReview)
        let accepted = Item(name: "Accepted", category: "shoe", reviewedAt: .distantPast)
        for item in [pendingA, pendingB, accepted] { fixture.context.insert(item) }
        try fixture.context.save()

        try WardrobeStore(modelContext: fixture.context)
            .acceptPendingItems([pendingA, pendingB, accepted], reviewedAt: reviewedAt)

        #expect(pendingA.reviewState == .accepted && pendingA.reviewedAt == reviewedAt)
        #expect(pendingB.reviewState == .accepted && pendingB.reviewedAt == reviewedAt)
        #expect(accepted.reviewedAt == .distantPast)
    }

    @Test func favoriteAndArchiveAreTransactionalAndAccountScoped() throws {
        let fixture = try makeFixture()
        let accountA = WardrobeAccountScope.external(.external("account-a"))
        let accountB = WardrobeAccountScope.external(.external("account-b"))
        let item = Item(
            name: "Imported",
            category: "top",
            source: .email,
            accountSubjectKey: accountA.rawValue
        )
        fixture.context.insert(item)
        try fixture.context.save()

        let storeA = WardrobeStore(modelContext: fixture.context, accountScope: accountA)
        try storeA.setFavorite(true, for: item)
        try storeA.setArchived(true, for: item)
        #expect(item.isFavorite && item.isArchived)

        let error = try capturePersistenceError {
            try WardrobeStore(modelContext: fixture.context, accountScope: accountB)
                .setArchived(false, for: item)
        }
        #expect(error.diagnostic.contains("itemOutsideAccountScope"))
        #expect(item.isArchived)
    }

    @Test func deleteCommitsTheRemoval() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let item = try seedItem(in: context)

        try WardrobeStore(modelContext: context).deleteItem(item)

        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func deletingDuplicatePrimaryPromotesAndRelinksRemainingEvidence() throws {
        let fixture = try makeFixture()
        let primary = Item(name: "Same", category: "top")
        let duplicateA = Item(
            name: "Same", category: "top", possibleDuplicateOfItemID: primary.id
        )
        let duplicateB = Item(
            name: "Same", category: "top", possibleDuplicateOfItemID: primary.id
        )
        for item in [primary, duplicateA, duplicateB] { fixture.context.insert(item) }
        try fixture.context.save()

        try WardrobeStore(modelContext: fixture.context).deleteItem(primary)

        let remaining = try fixture.context.fetch(FetchDescriptor<Item>())
        #expect(remaining.count == 2)
        let promoted = try #require(remaining.first { $0.possibleDuplicateOfItemID == nil })
        let linked = try #require(remaining.first { $0.possibleDuplicateOfItemID != nil })
        #expect(linked.possibleDuplicateOfItemID == promoted.id)
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
        #expect(outfits.first?.accountSubjectKey == WardrobeAccountScope.deviceLocal.rawValue)
        #expect(Set(outfits.first?.items.map(\.id) ?? []) == [shirt.id, trousers.id])
        #expect(wearLogs.count == 2)
        #expect(wearLogs.allSatisfy { $0.date == date && $0.outfit?.id == outfit.id })
        #expect(wearLogs.allSatisfy {
            $0.accountSubjectKey == WardrobeAccountScope.deviceLocal.rawValue
        })
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

    @Test func recordWearRejectsAnImportedItemFromAnotherAccount() throws {
        let fixture = try makeFixture()
        let accountA = WardrobeAccountScope.external(.external("account-a"))
        let accountB = WardrobeAccountScope.external(.external("account-b"))
        let imported = Item(
            name: "Account A shirt",
            category: "top",
            source: .email,
            accountSubjectKey: accountA.rawValue
        )
        fixture.context.insert(imported)
        try fixture.context.save()
        var saveCalls = 0
        let store = WardrobeStore(
            modelContext: fixture.context,
            accountScope: accountB,
            save: { context in
                saveCalls += 1
                try context.save()
            }
        )

        let error = try capturePersistenceError {
            try store.recordWear(
                items: [imported],
                occasion: nil,
                rationale: nil,
                colorStory: nil,
                date: .now
            )
        }

        #expect(error.operation == .recordWear)
        #expect(error.diagnostic.contains("itemOutsideAccountScope"))
        #expect(saveCalls == 0)
        #expect(try fixture.context.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<WearLog>()).isEmpty)
    }

    @Test func recordWearRejectsPendingAndArchivedItems() throws {
        let fixture = try makeFixture()
        let pending = Item(
            name: "Pending", category: "top", source: .email,
            accountSubjectKey: WardrobeAccountScope.deviceLocal.rawValue,
            reviewState: .pendingReview
        )
        let archived = Item(name: "Archived", category: "shoe", isArchived: true)
        for item in [pending, archived] { fixture.context.insert(item) }
        try fixture.context.save()

        for item in [pending, archived] {
            let error = try capturePersistenceError {
                try WardrobeStore(modelContext: fixture.context).recordWear(
                    items: [item], occasion: nil, rationale: nil, colorStory: nil, date: .now
                )
            }
            #expect(error.diagnostic.contains("itemNotStyleable"))
        }
        #expect(try fixture.context.fetch(FetchDescriptor<Outfit>()).isEmpty)
    }

    @Test func rateOutfitUpdatesEveryLogForOnlyThatOutfit() throws {
        let fixture = try makeFixture()
        let itemA = try seedItem(in: fixture.context, name: "A")
        let itemB = try seedItem(in: fixture.context, name: "B")
        let store = WardrobeStore(modelContext: fixture.context)
        let target = try store.recordWear(
            items: [itemA, itemB], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )
        let other = try store.recordWear(
            items: [itemA], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )

        try store.rateOutfit(target, feedback: 4)

        let logs = try fixture.context.fetch(FetchDescriptor<WearLog>())
        #expect(logs.filter { $0.outfit?.id == target.id }.allSatisfy { $0.feedback == 4 })
        #expect(logs.filter { $0.outfit?.id == other.id }.allSatisfy { $0.feedback == nil })
        #expect(!fixture.context.hasChanges)
    }

    @Test func rateOutfitNeverMutatesACrossAccountLogEvenIfItReferencesTheOutfit() throws {
        let fixture = try makeFixture()
        let accountA = WardrobeAccountScope.external(.external("rating-log-a"))
        let accountB = WardrobeAccountScope.external(.external("rating-log-b"))
        let item = try seedItem(in: fixture.context)
        let outfit = try WardrobeStore(
            modelContext: fixture.context,
            accountScope: accountA
        ).recordWear(
            items: [item], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )
        let foreignLog = WearLog(
            item: item,
            outfit: outfit,
            feedback: 1,
            accountSubjectKey: accountB.rawValue
        )
        fixture.context.insert(foreignLog)
        try fixture.context.save()

        try WardrobeStore(modelContext: fixture.context, accountScope: accountA)
            .rateOutfit(outfit, feedback: 5)

        let logs = try fixture.context.fetch(FetchDescriptor<WearLog>())
        #expect(logs.first { $0.accountSubjectKey == accountA.rawValue }?.feedback == 5)
        #expect(logs.first { $0.accountSubjectKey == accountB.rawValue }?.feedback == 1)
    }

    @Test(arguments: [0, 6, -1])
    func rateOutfitRejectsFeedbackOutsideOneThroughFive(feedback: Int) throws {
        let fixture = try makeFixture()
        let item = try seedItem(in: fixture.context)
        let outfit = try WardrobeStore(modelContext: fixture.context).recordWear(
            items: [item], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )

        let error = try capturePersistenceError {
            try WardrobeStore(modelContext: fixture.context).rateOutfit(outfit, feedback: feedback)
        }

        #expect(error.operation == .rateOutfit)
        #expect(error.diagnostic.contains("invalidOutfitFeedback"))
        #expect(try fixture.context.fetch(FetchDescriptor<WearLog>()).allSatisfy {
            $0.feedback == nil
        })
    }

    @Test(arguments: [1, 5])
    func rateOutfitAcceptsInclusiveBoundaryValues(feedback: Int) throws {
        let fixture = try makeFixture()
        let item = try seedItem(in: fixture.context)
        let outfit = try WardrobeStore(modelContext: fixture.context).recordWear(
            items: [item], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )

        try WardrobeStore(modelContext: fixture.context)
            .rateOutfit(outfit, feedback: feedback)

        #expect(try fixture.context.fetch(FetchDescriptor<WearLog>()).map(\.feedback)
            == [feedback])
    }

    @Test func rateOutfitRejectsForeignStoreAndAccount() throws {
        let destination = try makeFixture()
        let source = try makeFixture()
        let item = try seedItem(in: source.context)
        let sourceOutfit = try WardrobeStore(modelContext: source.context).recordWear(
            items: [item], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )

        let foreignError = try capturePersistenceError {
            try WardrobeStore(modelContext: destination.context)
                .rateOutfit(sourceOutfit, feedback: 3)
        }
        #expect(foreignError.diagnostic.contains("outfitFromDifferentStore"))

        let accountA = WardrobeAccountScope.external(.external("rating-a"))
        let accountB = WardrobeAccountScope.external(.external("rating-b"))
        let scopedItem = Item(name: "Scoped", category: "top")
        destination.context.insert(scopedItem)
        try destination.context.save()
        let scopedOutfit = try WardrobeStore(
            modelContext: destination.context, accountScope: accountA
        ).recordWear(
            items: [scopedItem], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )
        let accountError = try capturePersistenceError {
            try WardrobeStore(modelContext: destination.context, accountScope: accountB)
                .rateOutfit(scopedOutfit, feedback: 3)
        }
        #expect(accountError.diagnostic.contains("outfitOutsideAccountScope"))
    }

    @Test func rateOutfitRejectsAnOutfitWithoutWearLogs() throws {
        let fixture = try makeFixture()
        let outfit = Outfit(accountSubjectKey: WardrobeAccountScope.deviceLocal.rawValue)
        fixture.context.insert(outfit)
        try fixture.context.save()

        let error = try capturePersistenceError {
            try WardrobeStore(modelContext: fixture.context).rateOutfit(outfit, feedback: 5)
        }

        #expect(error.operation == .rateOutfit)
        #expect(error.diagnostic.contains("outfitHasNoWearLogs"))
    }

    @Test func failedOutfitRatingRollsBackEveryPriorRating() throws {
        let fixture = try makeFixture()
        let itemA = try seedItem(in: fixture.context, name: "A")
        let itemB = try seedItem(in: fixture.context, name: "B")
        let outfit = try WardrobeStore(modelContext: fixture.context).recordWear(
            items: [itemA, itemB], occasion: nil, rationale: nil, colorStory: nil, date: .now
        )
        for log in try fixture.context.fetch(FetchDescriptor<WearLog>()) {
            log.feedback = 2
        }
        try fixture.context.save()

        let error = try capturePersistenceError {
            try failingStore(fixture.context).rateOutfit(outfit, feedback: 5)
        }

        let verification = ModelContext(fixture.container)
        #expect(error.operation == .rateOutfit)
        #expect(error.diagnostic.contains("saveFailed"))
        #expect(try verification.fetch(FetchDescriptor<WearLog>()).allSatisfy {
            $0.feedback == 2
        })
        #expect(!fixture.context.hasChanges)
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
