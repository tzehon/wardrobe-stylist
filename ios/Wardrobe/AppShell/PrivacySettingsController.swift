import Foundation
import Observation

/// Device-scoped AI styling choices. Gmail account changes must not move the
/// styling consent itself, although signing out deliberately turns its reminder
/// off as part of the app-wide automation shutdown.
@MainActor
@Observable
final class DevicePrivacySettings {
    let controls: PrivacyControls
    let automation: PrivacyAutomationCoordinator

    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    var reminderTime: DailyReminderTime {
        automation.reminderTime
    }

    init(
        store: any PrivacyPreferencesStoring = UserDefaultsPrivacyPreferencesStore()
    ) {
        let controls = PrivacyControls(subjectID: .deviceLocal, store: store)
        self.controls = controls
        self.automation = PrivacyAutomationCoordinator(controls: controls)
    }

    init(
        controls: PrivacyControls,
        automation: PrivacyAutomationCoordinator
    ) {
        self.controls = controls
        self.automation = automation
    }

    func load() async {
        guard controls.preferences == nil else { return }
        await controls.load()
        if case .unavailable(let failure) = controls.state {
            errorMessage = failure.userMessage
        }
    }

    @discardableResult
    func grantStyling() async -> Bool {
        await performControlsUpdate {
            try await controls.grantWardrobeStyling()
        }
    }

    @discardableResult
    func withdrawStyling() async -> Bool {
        await performAutomationUpdate {
            await automation.withdrawWardrobeStyling()
        }
    }

    @discardableResult
    func setReminderEnabled(
        _ isEnabled: Bool,
        time: DailyReminderTime? = nil
    ) async -> Bool {
        await performAutomationUpdate {
            await automation.setDailyReminderEnabled(
                isEnabled,
                time: time ?? automation.reminderTime
            )
        }
    }

    /// Available to a Settings time picker only while the reminder is enabled.
    /// Choosing a time does not itself request notification authorization.
    @discardableResult
    func setReminderTime(_ time: DailyReminderTime) async -> Bool {
        await performAutomationUpdate {
            await automation.setDailyReminderTime(time)
        }
    }

    /// Used before a Google sign-out/disconnect. This intentionally preserves
    /// the device-local styling grant while turning the pending reminder off.
    @discardableResult
    func disableReminderForAccountExit() async -> Bool {
        await load()
        return await setReminderEnabled(false)
    }

    func clearError() {
        errorMessage = nil
    }

    private func performControlsUpdate(
        _ operation: () async throws -> Void
    ) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        await load()
        do {
            try await operation()
            return true
        } catch let failure as PrivacyControlsFailure {
            errorMessage = failure.userMessage
            return false
        } catch {
            errorMessage = PrivacyControlsFailure.saveFailed.userMessage
            return false
        }
    }

    private func performAutomationUpdate(
        _ operation: () async -> Bool
    ) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        await load()
        let succeeded = await operation()
        if !succeeded, case .failed(let failure) = automation.state {
            errorMessage = failure.userMessage
        }
        return succeeded
    }
}

/// Receipt-analysis choices for one stable Google identity. This controller
/// never uses the email address as a storage key.
@MainActor
@Observable
final class GmailPrivacySettings {
    let subjectID: PrivacySubjectID
    let controls: PrivacyControls
    let automation: PrivacyAutomationCoordinator

    private let store: any PrivacyPreferencesStoring
    private let devicePrivacy: DevicePrivacySettings

    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    init(
        subjectID: PrivacySubjectID,
        devicePrivacy: DevicePrivacySettings,
        store: any PrivacyPreferencesStoring = UserDefaultsPrivacyPreferencesStore()
    ) {
        let controls = PrivacyControls(subjectID: subjectID, store: store)
        self.subjectID = subjectID
        self.store = store
        self.devicePrivacy = devicePrivacy
        self.controls = controls
        self.automation = PrivacyAutomationCoordinator(controls: controls)
    }

    init(
        subjectID: PrivacySubjectID,
        store: any PrivacyPreferencesStoring,
        devicePrivacy: DevicePrivacySettings,
        controls: PrivacyControls,
        automation: PrivacyAutomationCoordinator
    ) {
        self.subjectID = subjectID
        self.store = store
        self.devicePrivacy = devicePrivacy
        self.controls = controls
        self.automation = automation
    }

    func load() async {
        guard controls.preferences == nil else { return }
        await controls.load()
        if case .unavailable(let failure) = controls.state {
            errorMessage = failure.userMessage
        }
    }

    @discardableResult
    func grantReceiptAnalysis() async -> Bool {
        await performControlsUpdate {
            try await controls.grantReceiptAnalysis()
        }
    }

    @discardableResult
    func withdrawReceiptAnalysis() async -> Bool {
        await performAutomationUpdate {
            await automation.withdrawReceiptAnalysis()
        }
    }

    @discardableResult
    func setBackgroundImportEnabled(_ isEnabled: Bool) async -> Bool {
        await performAutomationUpdate {
            await automation.setBackgroundReceiptSyncEnabled(isEnabled)
        }
    }

    /// A session exit is allowed only after both persisted automation switches
    /// and their pending OS work are off. Consent grants remain in place.
    @discardableResult
    func prepareForAccountExit() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        await load()
        let receiptSucceeded = await automation.setBackgroundReceiptSyncEnabled(false)
        guard receiptSucceeded else {
            captureAutomationError(from: automation)
            return false
        }

        let reminderSucceeded = await devicePrivacy.disableReminderForAccountExit()
        guard reminderSucceeded else {
            errorMessage = devicePrivacy.errorMessage
                ?? "The daily reminder couldn’t be turned off. Please try again."
            return false
        }
        return true
    }

    /// Called only after Google confirms OAuth revocation. It removes the
    /// stable-account receipt choices; device-local styling choices remain.
    func clearRevokedAccountPreferences() async {
        await store.remove(for: subjectID)
        await controls.load()
    }

    func clearError() {
        errorMessage = nil
    }

    private func performControlsUpdate(
        _ operation: () async throws -> Void
    ) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        await load()
        do {
            try await operation()
            return true
        } catch let failure as PrivacyControlsFailure {
            errorMessage = failure.userMessage
            return false
        } catch {
            errorMessage = PrivacyControlsFailure.saveFailed.userMessage
            return false
        }
    }

    private func performAutomationUpdate(
        _ operation: () async -> Bool
    ) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        await load()
        let succeeded = await operation()
        if !succeeded {
            captureAutomationError(from: automation)
        }
        return succeeded
    }

    private func captureAutomationError(from coordinator: PrivacyAutomationCoordinator) {
        if case .failed(let failure) = coordinator.state {
            errorMessage = failure.userMessage
        } else {
            errorMessage = "Your privacy choice couldn’t be updated. Please try again."
        }
    }
}
