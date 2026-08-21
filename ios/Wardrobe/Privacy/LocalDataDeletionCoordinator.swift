import Foundation
import Observation
import SwiftData

enum LocalDataDeletionScope: Equatable, Sendable {
    case all
}

struct LocalDataDeletionCounts: Equatable, Sendable {
    let items: Int
    let outfits: Int
    let wearLogs: Int

    static let zero = Self(items: 0, outfits: 0, wearLogs: 0)
    var isEmpty: Bool { self == .zero }
}

struct LocalDataDeletionFailure: Error, Equatable, LocalizedError, Sendable {
    enum Stage: Equatable, Sendable {
        case persistence
        case verification
        case preferences
    }

    let stage: Stage
    let diagnostic: String

    var errorDescription: String? { "Couldn’t Delete Local Data" }
    var recoverySuggestion: String? {
        switch stage {
        case .preferences:
            "Your wardrobe and reminder were removed, but some app settings may remain. Please try Delete Local Data again."
        case .persistence, .verification:
            "Some local data may remain. Nothing was reported as successfully deleted; please try again."
        }
    }
}

struct ConfirmedLocalDataDeletion: Sendable {
    fileprivate init() {}
}

struct LocalDataDeletionConfirmation: Equatable, Sendable {
    let title = "Delete local data?"
    let message = "This permanently removes your wardrobe, outfit history, cached looks, reminder, and related choices from this device. This cannot be undone."
    let destructiveActionTitle = "Delete Local Data"

    func confirm() -> ConfirmedLocalDataDeletion { ConfirmedLocalDataDeletion() }
}

@MainActor
@Observable
final class LocalDataDeletionCoordinator {
    enum State: Equatable {
        case idle
        case deleting
        case succeeded(LocalDataDeletionCounts)
        case failed(LocalDataDeletionFailure)
    }

    typealias Save = @MainActor (ModelContext) throws -> Void
    typealias DisableSystemWork = @MainActor () -> Void
    typealias ClearAllPreferences = @MainActor () async -> Bool
    typealias ClearAllCaches = @MainActor () -> Bool

    private(set) var state: State = .idle

    private let modelContext: ModelContext
    private let disableSystemWork: DisableSystemWork
    private let clearAllPreferences: ClearAllPreferences
    private let clearAllCaches: ClearAllCaches
    private let clearReminderTime: @MainActor () -> Bool
    private let clearNavigationSignal: @MainActor () -> Bool
    private let save: Save

    init(
        modelContext: ModelContext,
        disableSystemWork: @escaping DisableSystemWork = {
            DailyOutfitNotifier().disableDailyReminder()
        },
        clearAllPreferences: @escaping ClearAllPreferences = {
            UserDefaultsPrivacyPreferencesStore().removeAllAppOwnedPreferencesAndVerify()
        },
        clearAllCaches: @escaping ClearAllCaches = {
            UserDefaultsDailyLookCache().removeAllAppOwnedEntriesAndVerify()
        },
        clearReminderTime: @escaping @MainActor () -> Bool = {
            UserDefaultsDailyReminderTimeStore().removeAndVerify()
        },
        clearNavigationSignal: @escaping @MainActor () -> Bool = {
            UserDefaultsAppNavigationSignalStore().clearAndVerify()
        },
        save: @escaping Save = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.disableSystemWork = disableSystemWork
        self.clearAllPreferences = clearAllPreferences
        self.clearAllCaches = clearAllCaches
        self.clearReminderTime = clearReminderTime
        self.clearNavigationSignal = clearNavigationSignal
        self.save = save
    }

    @discardableResult
    func delete(
        scope: LocalDataDeletionScope = .all,
        confirmedBy confirmation: ConfirmedLocalDataDeletion
    ) async -> Bool {
        _ = scope
        _ = confirmation
        guard state != .deleting else { return false }
        state = .deleting

        let before: LocalDataDeletionCounts
        do {
            guard !modelContext.hasChanges else {
                throw LocalDataDeletionInternalFailure.pendingChanges
            }
            before = try counts()
            for model in try modelContext.fetch(FetchDescriptor<WearLog>()) {
                modelContext.delete(model)
            }
            for model in try modelContext.fetch(FetchDescriptor<Outfit>()) {
                modelContext.delete(model)
            }
            for model in try modelContext.fetch(FetchDescriptor<Item>()) {
                modelContext.delete(model)
            }
            try save(modelContext)
        } catch {
            if !(error is LocalDataDeletionInternalFailure) {
                modelContext.rollback()
            }
            return fail(.persistence, String(describing: error))
        }

        do {
            guard try counts().isEmpty else {
                return fail(.verification, "Local model rows remain after deletion")
            }
        } catch {
            return fail(.verification, String(describing: error))
        }

        // Model deletion is committed and verified. Cancel the system-facing
        // reminder now so a later app-owned preference/cache cleanup failure
        // cannot leave a notification scheduled for a deleted wardrobe.
        disableSystemWork()

        var cleared = await clearAllPreferences()
        if !clearAllCaches() { cleared = false }
        if !clearReminderTime() { cleared = false }
        if !clearNavigationSignal() { cleared = false }
        guard cleared else {
            return fail(.preferences, "App-owned preferences could not be cleared")
        }

        state = .succeeded(before)
        return true
    }

    func resetResult() {
        guard state != .deleting else { return }
        state = .idle
    }

    private func counts() throws -> LocalDataDeletionCounts {
        LocalDataDeletionCounts(
            items: try modelContext.fetchCount(FetchDescriptor<Item>()),
            outfits: try modelContext.fetchCount(FetchDescriptor<Outfit>()),
            wearLogs: try modelContext.fetchCount(FetchDescriptor<WearLog>())
        )
    }

    @discardableResult
    private func fail(_ stage: LocalDataDeletionFailure.Stage, _ diagnostic: String) -> Bool {
        state = .failed(LocalDataDeletionFailure(stage: stage, diagnostic: diagnostic))
        return false
    }

    private enum LocalDataDeletionInternalFailure: Error {
        case pendingChanges
    }
}
