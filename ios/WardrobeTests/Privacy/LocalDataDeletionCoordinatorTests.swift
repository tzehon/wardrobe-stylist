import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct LocalDataDeletionCoordinatorTests {
    @Test func confirmationCoversAllDeviceLocalData() {
        let confirmation = LocalDataDeletionConfirmation()
        #expect(confirmation.title == "Delete local data?")
        #expect(confirmation.message.contains("wardrobe"))
        #expect(confirmation.message.contains("reminder"))
        #expect(confirmation.message.contains("cannot be undone"))
    }

    @Test func deletionRemovesModelsDisablesReminderAndClearsPreferences() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        let item = Item(name: "Shirt", category: "top")
        let outfit = Outfit(items: [item])
        context.insert(item)
        context.insert(outfit)
        context.insert(WearLog(item: item, outfit: outfit))
        try context.save()

        var disabled = 0
        var preferencesCleared = 0
        var cacheCleared = 0
        var events: [String] = []
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: context,
            disableSystemWork: {
                disabled += 1
                events.append("disable")
            },
            clearAllPreferences: {
                preferencesCleared += 1
                events.append("preferences")
                return true
            },
            clearAllCaches: { cacheCleared += 1; return true },
            clearReminderTime: { true },
            clearNavigationSignal: { true }
        )
        #expect(await coordinator.delete(
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ))
        #expect(coordinator.state == .succeeded(LocalDataDeletionCounts(
            items: 1, outfits: 1, wearLogs: 1
        )))
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WearLog>()) == 0)
        #expect(disabled == 1)
        #expect(preferencesCleared == 1)
        #expect(cacheCleared == 1)
        #expect(events == ["disable", "preferences"])
    }

    @Test func pendingContextFailsWithoutDeletingRows() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        context.insert(Item(name: "Unsaved", category: "top"))
        var disabled = 0
        var preferencesCleared = 0
        var savedReminderPreferenceEnabled = true
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: context,
            disableSystemWork: { disabled += 1 },
            clearAllPreferences: {
                preferencesCleared += 1
                savedReminderPreferenceEnabled = false
                return true
            },
            clearAllCaches: { true },
            clearReminderTime: { true },
            clearNavigationSignal: { true }
        )
        #expect(await coordinator.delete(
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected a deletion failure")
            return
        }
        #expect(failure.stage == .persistence)
        #expect(disabled == 0)
        #expect(preferencesCleared == 0)
        #expect(savedReminderPreferenceEnabled)
        #expect(context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
    }

    @Test func saveFailureKeepsRowsPreferencesAndSystemReminderEnabled() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        context.insert(Item(name: "Saved", category: "top"))
        try context.save()

        var disabled = 0
        var preferencesCleared = 0
        var savedReminderPreferenceEnabled = true
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: context,
            disableSystemWork: { disabled += 1 },
            clearAllPreferences: {
                preferencesCleared += 1
                savedReminderPreferenceEnabled = false
                return true
            },
            clearAllCaches: { true },
            clearReminderTime: { true },
            clearNavigationSignal: { true },
            save: { _ in throw InjectedSaveFailure() }
        )

        #expect(await coordinator.delete(
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected a deletion failure")
            return
        }
        #expect(failure.stage == .persistence)
        #expect(disabled == 0)
        #expect(preferencesCleared == 0)
        #expect(savedReminderPreferenceEnabled)
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
    }

    @Test func preferenceFailureStillCancelsSystemReminderAfterVerifiedModelDeletion() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        context.insert(Item(name: "Saved", category: "top"))
        try context.save()

        var disabled = 0
        var events: [String] = []
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: context,
            disableSystemWork: {
                disabled += 1
                events.append("disable")
            },
            clearAllPreferences: {
                events.append("preferences")
                return false
            },
            clearAllCaches: { true },
            clearReminderTime: { true },
            clearNavigationSignal: { true }
        )

        #expect(await coordinator.delete(
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected a deletion failure")
            return
        }
        #expect(failure.stage == .preferences)
        #expect(failure.recoverySuggestion?.contains("wardrobe and reminder were removed") == true)
        #expect(disabled == 1)
        #expect(events == ["disable", "preferences"])
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    }
}

private struct InjectedSaveFailure: Error {}
