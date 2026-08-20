import Foundation
import Observation

enum PrivacyAutomationFailure: Error, Equatable, Sendable {
    case stylingConsentRequired
    case notificationPermissionDenied
    case preferenceSaveFailed

    var userMessage: String {
        switch self {
        case .stylingConsentRequired:
            "Allow AI styling before enabling a daily reminder."
        case .notificationPermissionDenied:
            "Notifications are off in Settings. The daily reminder remains off."
        case .preferenceSaveFailed:
            "Your choice couldn’t be saved. Please try again."
        }
    }
}

@MainActor
@Observable
final class PrivacyAutomationCoordinator {
    enum State: Equatable {
        case idle
        case updating
        case ready
        case failed(PrivacyAutomationFailure)
    }

    private(set) var state: State = .idle

    private let controls: PrivacyControls
    private let enableReminder: @MainActor (DailyReminderTime) async throws -> Bool
    private let disableReminder: @MainActor () -> Void
    private let reminderTimeStore: any DailyReminderTimeStoring

    init(
        controls: PrivacyControls,
        enableReminder: @escaping @MainActor (DailyReminderTime) async throws -> Bool = { time in
            try await DailyOutfitNotifier().enableDailyReminder(time: time)
        },
        disableReminder: @escaping @MainActor () -> Void = {
            DailyOutfitNotifier().disableDailyReminder()
        },
        reminderTimeStore: any DailyReminderTimeStoring = UserDefaultsDailyReminderTimeStore()
    ) {
        self.controls = controls
        self.enableReminder = enableReminder
        self.disableReminder = disableReminder
        self.reminderTimeStore = reminderTimeStore
    }

    var reminderTime: DailyReminderTime { reminderTimeStore.load() }

    @discardableResult
    func setDailyReminderEnabled(
        _ isEnabled: Bool,
        time: DailyReminderTime = .defaultMorning
    ) async -> Bool {
        state = .updating
        if isEnabled {
            guard controls.decision(for: .aiStyling).isAllowed else {
                state = .failed(.stylingConsentRequired)
                return false
            }
            do {
                guard try await enableReminder(time) else {
                    state = .failed(.notificationPermissionDenied)
                    return false
                }
                try await controls.setDailyReminderEnabled(true)
                guard reminderTimeStore.save(time) else {
                    try? await controls.setDailyReminderEnabled(false)
                    disableReminder()
                    state = .failed(.preferenceSaveFailed)
                    return false
                }
                state = .ready
                return true
            } catch let failure as PrivacyControlsFailure
                where failure == .saveFailed || failure == .preferencesUnavailable {
                disableReminder()
                state = .failed(.preferenceSaveFailed)
                return false
            } catch {
                disableReminder()
                state = .failed(.notificationPermissionDenied)
                return false
            }
        }

        do {
            try await controls.setDailyReminderEnabled(false)
            disableReminder()
            state = .ready
            return true
        } catch {
            state = .failed(.preferenceSaveFailed)
            return false
        }
    }

    @discardableResult
    func setDailyReminderTime(_ time: DailyReminderTime) async -> Bool {
        state = .updating
        guard controls.decision(for: .dailyReminder).isAllowed else {
            state = .failed(.stylingConsentRequired)
            return false
        }
        let priorTime = reminderTimeStore.load()
        do {
            guard try await enableReminder(time) else {
                state = .failed(.notificationPermissionDenied)
                return false
            }
            guard reminderTimeStore.save(time) else {
                let restored = (try? await enableReminder(priorTime)) == true
                if !restored {
                    try? await controls.setDailyReminderEnabled(false)
                    disableReminder()
                }
                state = .failed(.preferenceSaveFailed)
                return false
            }
            state = .ready
            return true
        } catch {
            state = .failed(.notificationPermissionDenied)
            return false
        }
    }

    @discardableResult
    func withdrawWardrobeStyling() async -> Bool {
        state = .updating
        do {
            try await controls.withdrawWardrobeStyling()
            disableReminder()
            state = .ready
            return true
        } catch {
            state = .failed(.preferenceSaveFailed)
            return false
        }
    }

    func reconcile() async {
        if controls.preferences == nil { await controls.load() }
        guard let preferences = controls.preferences else {
            disableReminder()
            state = .failed(.preferenceSaveFailed)
            return
        }
        guard controls.decision(for: .dailyReminder).isAllowed else {
            disableReminder()
            if preferences.dailyReminderEnabled {
                do {
                    try await controls.setDailyReminderEnabled(false)
                } catch {
                    state = .failed(.preferenceSaveFailed)
                    return
                }
            }
            state = .ready
            return
        }
        state = .ready
    }
}
