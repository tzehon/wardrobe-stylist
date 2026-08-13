import Foundation
import Observation
import SwiftData

enum LocalDataDeletionScope: Equatable, Sendable {
    /// Removes all locally held wardrobe/history/sync data and every app-owned
    /// account preference/cache. This is the Settings "Delete Local Data"
    /// action. The associated value is retained for UI context/copy; the
    /// namespaced purge does not depend on it.
    case all(activeExternalSubject: PrivacySubjectID?)

    /// Removes only one account's imported items, history, cursors and receipt
    /// preferences. Shared manual/photo items, device styling preferences and
    /// other account records remain intact.
    case externalAccount(PrivacySubjectID)
}

struct LocalDataDeletionCounts: Equatable, Sendable {
    let items: Int
    let outfits: Int
    let wearLogs: Int
    let processedGmailMessages: Int
    let gmailSyncStates: Int

    static let zero = Self(
        items: 0,
        outfits: 0,
        wearLogs: 0,
        processedGmailMessages: 0,
        gmailSyncStates: 0
    )

    var isEmpty: Bool {
        self == .zero
    }
}

struct LocalDataDeletionFailure: Error, Equatable, LocalizedError, Sendable {
    enum Stage: Equatable, Sendable {
        case syncDidNotStop
        case persistence
        case verification
        case preferences
    }

    let stage: Stage
    let diagnostic: String

    var errorDescription: String? { "Couldn’t Delete Local Data" }

    var recoverySuggestion: String? {
        switch stage {
        case .syncDidNotStop:
            "Receipt import is still stopping. Wait a moment, then try again."
        case .persistence, .verification, .preferences:
            "Some local data may remain. Nothing was reported as successfully deleted; please try again."
        }
    }
}

/// Confirmation token intentionally cannot be constructed by a view without
/// first showing the destructive confirmation copy supplied here.
struct ConfirmedLocalDataDeletion: Sendable {
    fileprivate init() {}
}

struct LocalDataDeletionConfirmation: Equatable, Sendable {
    let title = "Delete local data?"
    let message = "This permanently removes the selected wardrobe, outfit history, receipt sync history, cached images, and related choices from this device. It does not revoke Google access; Disconnect Google is a separate action. This cannot be undone."
    let destructiveActionTitle = "Delete Local Data"

    func confirm() -> ConfirmedLocalDataDeletion {
        ConfirmedLocalDataDeletion()
    }
}

/// Coordinates the destructive operation in a strict order: stop/wait for
/// in-flight imports, remove pending system work, commit model deletion, verify
/// the selected scope is empty, then clear only the relevant preferences and
/// caches. Success is published only after every stage finishes.
@MainActor
@Observable
final class LocalDataDeletionCoordinator {
    enum State: Equatable {
        case idle
        case deleting
        case succeeded(LocalDataDeletionCounts)
        case failed(LocalDataDeletionFailure)
    }

    typealias StopInFlightSync = @MainActor () async -> Bool
    typealias Save = @MainActor (ModelContext) throws -> Void
    typealias DisableSystemWork = @MainActor () -> Void
    typealias ClearPreference = @MainActor (PrivacySubjectID) async -> Bool
    typealias ClearAllPreferences = @MainActor () async -> Bool
    typealias ClearCache = @MainActor (WardrobeAccountScope) -> Bool
    typealias ClearAllCaches = @MainActor () -> Bool
    typealias ClearRemoteImages = @MainActor () async -> Bool

    private(set) var state: State = .idle

    private let modelContext: ModelContext
    private let stopInFlightSync: StopInFlightSync
    private let disableSystemWork: DisableSystemWork
    private let clearPreference: ClearPreference
    private let clearAllPreferences: ClearAllPreferences
    private let clearCache: ClearCache
    private let clearAllCaches: ClearAllCaches
    private let clearRemoteImages: ClearRemoteImages
    private let clearReminderTime: @MainActor () -> Bool
    private let clearNavigationSignal: @MainActor () -> Bool
    private let save: Save

    init(
        modelContext: ModelContext,
        stopInFlightSync: @escaping StopInFlightSync = { true },
        disableSystemWork: @escaping DisableSystemWork = {
            ReceiptSyncScheduler.cancel()
            DailyOutfitNotifier().disableDailyReminder()
        },
        clearPreference: @escaping ClearPreference = { subjectID in
            await UserDefaultsPrivacyPreferencesStore().removeAndVerify(for: subjectID)
        },
        clearAllPreferences: @escaping ClearAllPreferences = {
            await UserDefaultsPrivacyPreferencesStore().removeAllAppOwnedPreferencesAndVerify()
        },
        clearCache: @escaping ClearCache = { scope in
            UserDefaultsDailyLookCache().removeAndVerify(for: scope)
        },
        clearAllCaches: @escaping ClearAllCaches = {
            UserDefaultsDailyLookCache().removeAllAppOwnedEntriesAndVerify()
        },
        clearRemoteImages: @escaping ClearRemoteImages = {
            await RemoteImageLoader.shared.clearCachedImages()
            return true
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
        self.stopInFlightSync = stopInFlightSync
        self.disableSystemWork = disableSystemWork
        self.clearPreference = clearPreference
        self.clearAllPreferences = clearAllPreferences
        self.clearCache = clearCache
        self.clearAllCaches = clearAllCaches
        self.clearRemoteImages = clearRemoteImages
        self.clearReminderTime = clearReminderTime
        self.clearNavigationSignal = clearNavigationSignal
        self.save = save
    }

    @discardableResult
    func delete(
        scope: LocalDataDeletionScope,
        confirmedBy confirmation: ConfirmedLocalDataDeletion
    ) async -> Bool {
        _ = confirmation
        guard state != .deleting else { return false }
        state = .deleting

        guard await stopInFlightSync() else {
            return fail(.syncDidNotStop, "In-flight receipt import did not confirm cancellation")
        }
        disableSystemWork()

        let before: LocalDataDeletionCounts
        do {
            try requireCleanContext()
            before = try counts(in: scope)
            try deleteModels(in: scope)
            try save(modelContext)
        } catch {
            // Roll back only a transaction we started. Pre-existing unrelated
            // pending edits are left untouched and make deletion fail closed.
            if !beforeDeletionWasBlocked(error) {
                modelContext.rollback()
            }
            return fail(.persistence, String(describing: error))
        }

        do {
            let remaining = try counts(in: scope)
            guard remaining.isEmpty else {
                return fail(.verification, "Selected rows remain: \(remaining)")
            }
        } catch {
            return fail(.verification, String(describing: error))
        }

        guard await clearPreferencesAndCaches(for: scope) else {
            return fail(.preferences, "Relevant preferences could not be cleared")
        }

        state = .succeeded(before)
        return true
    }

    func resetResult() {
        guard state != .deleting else { return }
        state = .idle
    }

    private func deleteModels(in scope: LocalDataDeletionScope) throws {
        // Relationships are detached explicitly by deleting wear logs/outfits
        // before items. SwiftData external-storage blobs are owned by their
        // model attributes and are reclaimed with the item rows.
        for model in try selectedWearLogs(in: scope) { modelContext.delete(model) }
        for model in try selectedOutfits(in: scope) { modelContext.delete(model) }
        for model in try selectedItems(in: scope) { modelContext.delete(model) }
        for model in try selectedProcessedMessages(in: scope) { modelContext.delete(model) }
        for model in try selectedSyncStates(in: scope) { modelContext.delete(model) }
    }

    private func counts(in scope: LocalDataDeletionScope) throws -> LocalDataDeletionCounts {
        LocalDataDeletionCounts(
            items: try selectedItems(in: scope).count,
            outfits: try selectedOutfits(in: scope).count,
            wearLogs: try selectedWearLogs(in: scope).count,
            processedGmailMessages: try selectedProcessedMessages(in: scope).count,
            gmailSyncStates: try selectedSyncStates(in: scope).count
        )
    }

    private func selectedItems(in scope: LocalDataDeletionScope) throws -> [Item] {
        let all = try modelContext.fetch(FetchDescriptor<Item>())
        switch scope {
        case .all:
            return all
        case .externalAccount(let subjectID):
            let key = WardrobeAccountScope.external(subjectID).rawValue
            return all.filter { $0.source == .email && $0.accountSubjectKey == key }
        }
    }

    private func selectedOutfits(in scope: LocalDataDeletionScope) throws -> [Outfit] {
        filterByScope(try modelContext.fetch(FetchDescriptor<Outfit>()), scope: scope) {
            $0.accountSubjectKey
        }
    }

    private func selectedWearLogs(in scope: LocalDataDeletionScope) throws -> [WearLog] {
        filterByScope(try modelContext.fetch(FetchDescriptor<WearLog>()), scope: scope) {
            $0.accountSubjectKey
        }
    }

    private func selectedProcessedMessages(
        in scope: LocalDataDeletionScope
    ) throws -> [ProcessedGmailMessage] {
        filterByScope(try modelContext.fetch(FetchDescriptor<ProcessedGmailMessage>()), scope: scope) {
            $0.accountSubjectKey
        }
    }

    private func selectedSyncStates(in scope: LocalDataDeletionScope) throws -> [GmailSyncState] {
        filterByScope(try modelContext.fetch(FetchDescriptor<GmailSyncState>()), scope: scope) {
            $0.accountSubjectKey
        }
    }

    private func filterByScope<Model>(
        _ models: [Model],
        scope: LocalDataDeletionScope,
        key: (Model) -> String?
    ) -> [Model] {
        switch scope {
        case .all:
            return models
        case .externalAccount(let subjectID):
            let selectedKey = WardrobeAccountScope.external(subjectID).rawValue
            return models.filter { key($0) == selectedKey }
        }
    }

    private func clearPreferencesAndCaches(for scope: LocalDataDeletionScope) async -> Bool {
        switch scope {
        case .all:
            // Prefix-scoped purges include signed-out accounts B/C/etc., not
            // only the currently connected account supplied with the action.
            var succeeded = await clearAllPreferences()
            if !clearAllCaches() { succeeded = false }
            if !clearReminderTime() { succeeded = false }
            if !clearNavigationSignal() { succeeded = false }
            if !(await clearRemoteImages()) { succeeded = false }
            return succeeded
        case .externalAccount(let subjectID):
            let preferenceRemoved = await clearPreference(subjectID)
            let cacheRemoved = clearCache(.external(subjectID))
            let remoteImagesRemoved = await clearRemoteImages()
            return preferenceRemoved && cacheRemoved && remoteImagesRemoved
        }
    }

    private func requireCleanContext() throws {
        guard !modelContext.hasChanges else {
            throw LocalDataDeletionInternalFailure.pendingChanges
        }
    }

    private func beforeDeletionWasBlocked(_ error: Error) -> Bool {
        guard let failure = error as? LocalDataDeletionInternalFailure else { return false }
        return failure == .pendingChanges
    }

    @discardableResult
    private func fail(_ stage: LocalDataDeletionFailure.Stage, _ diagnostic: String) -> Bool {
        state = .failed(LocalDataDeletionFailure(stage: stage, diagnostic: diagnostic))
        return false
    }

    private enum LocalDataDeletionInternalFailure: Error, Equatable {
        case pendingChanges
    }
}
