import Observation

@MainActor
@Observable
final class DevicePrivacySettings {
    let controls: PrivacyControls
    let automation: PrivacyAutomationCoordinator

    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    var reminderTime: DailyReminderTime { automation.reminderTime }

    init(store: any PrivacyPreferencesStoring = UserDefaultsPrivacyPreferencesStore()) {
        let controls = PrivacyControls(subjectID: .deviceLocal, store: store)
        self.controls = controls
        self.automation = PrivacyAutomationCoordinator(controls: controls)
    }

    init(controls: PrivacyControls, automation: PrivacyAutomationCoordinator) {
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
        await performControlsUpdate { try await controls.grantWardrobeStyling() }
    }

    @discardableResult
    func withdrawStyling() async -> Bool {
        await performAutomationUpdate { await automation.withdrawWardrobeStyling() }
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

    @discardableResult
    func setReminderTime(_ time: DailyReminderTime) async -> Bool {
        await performAutomationUpdate { await automation.setDailyReminderTime(time) }
    }

    func clearError() { errorMessage = nil }

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
