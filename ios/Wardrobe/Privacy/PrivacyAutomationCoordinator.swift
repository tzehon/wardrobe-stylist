import Foundation
import Observation

enum PrivacyAutomationFailure: Error, Equatable, Sendable {
    case receiptConsentRequired
    case stylingConsentRequired
    case backgroundSchedulingFailed
    case notificationPermissionDenied
    case preferenceSaveFailed

    var userMessage: String {
        switch self {
        case .receiptConsentRequired:
            "Allow receipt analysis before enabling background import."
        case .stylingConsentRequired:
            "Allow AI styling before enabling a daily reminder."
        case .backgroundSchedulingFailed:
            "Background import couldn’t be scheduled. It remains off."
        case .notificationPermissionDenied:
            "Notifications are off in Settings. The daily reminder remains off."
        case .preferenceSaveFailed:
            "Your choice couldn’t be saved. Please try again."
        }
    }
}

/// Coordinates persisted privacy choices with OS-owned background and
/// notification work. Enabling follows a two-phase pattern: establish the
/// system work first, then persist the switch; a failed save compensates by
/// removing that work. Disabling persists first and removes work second.
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
    private let scheduleBackground: @MainActor () throws -> Void
    private let cancelBackground: @MainActor () -> Void
    private let enableReminder: @MainActor (DailyReminderTime) async throws -> Bool
    private let disableReminder: @MainActor () -> Void

    init(
        controls: PrivacyControls,
        scheduleBackground: @escaping @MainActor () throws -> Void = {
            try ReceiptSyncScheduler.schedule()
        },
        cancelBackground: @escaping @MainActor () -> Void = {
            ReceiptSyncScheduler.cancel()
        },
        enableReminder: @escaping @MainActor (DailyReminderTime) async throws -> Bool = { time in
            try await DailyOutfitNotifier().enableDailyReminder(time: time)
        },
        disableReminder: @escaping @MainActor () -> Void = {
            DailyOutfitNotifier().disableDailyReminder()
        }
    ) {
        self.controls = controls
        self.scheduleBackground = scheduleBackground
        self.cancelBackground = cancelBackground
        self.enableReminder = enableReminder
        self.disableReminder = disableReminder
    }

    @discardableResult
    func setBackgroundReceiptSyncEnabled(_ isEnabled: Bool) async -> Bool {
        state = .updating
        if isEnabled {
            guard controls.decision(for: .manualReceiptImport).isAllowed else {
                state = .failed(.receiptConsentRequired)
                return false
            }
            do {
                try scheduleBackground()
            } catch {
                state = .failed(.backgroundSchedulingFailed)
                return false
            }
            do {
                try await controls.setBackgroundReceiptSyncEnabled(true)
                state = .ready
                return true
            } catch {
                cancelBackground()
                state = .failed(.preferenceSaveFailed)
                return false
            }
        }

        do {
            try await controls.setBackgroundReceiptSyncEnabled(false)
            cancelBackground()
            state = .ready
            return true
        } catch {
            state = .failed(.preferenceSaveFailed)
            return false
        }
    }

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
            } catch {
                state = .failed(.notificationPermissionDenied)
                return false
            }
            do {
                try await controls.setDailyReminderEnabled(true)
                state = .ready
                return true
            } catch {
                disableReminder()
                state = .failed(.preferenceSaveFailed)
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
    func withdrawReceiptAnalysis() async -> Bool {
        state = .updating
        do {
            try await controls.withdrawReceiptAnalysis()
            cancelBackground()
            state = .ready
            return true
        } catch {
            state = .failed(.preferenceSaveFailed)
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

    /// Fail-closed launch/sign-out reconciliation. Invalid or unavailable
    /// privacy state always removes pending work. Valid enabled automation is
    /// left intact and will be re-checked again at its execution boundary.
    func reconcile() async {
        if controls.preferences == nil {
            await controls.load()
        }

        guard let preferences = controls.preferences else {
            cancelBackground()
            disableReminder()
            state = .failed(.preferenceSaveFailed)
            return
        }

        let backgroundAllowed = controls.decision(for: .backgroundReceiptImport).isAllowed
        let reminderAllowed = controls.decision(for: .dailyReminder).isAllowed
        var saveFailed = false

        if !backgroundAllowed {
            cancelBackground()
            if preferences.backgroundReceiptSyncEnabled {
                do {
                    try await controls.setBackgroundReceiptSyncEnabled(false)
                } catch {
                    saveFailed = true
                }
            }
        }
        if !reminderAllowed {
            disableReminder()
            if preferences.dailyReminderEnabled {
                do {
                    try await controls.setDailyReminderEnabled(false)
                } catch {
                    saveFailed = true
                }
            }
        }
        state = saveFailed ? .failed(.preferenceSaveFailed) : .ready
    }

    /// Sign-out keeps consent grants and local data but disables both
    /// automations, requiring the user to opt in again after reconnecting.
    @discardableResult
    func disableAutomationsForSignOut() async -> Bool {
        state = .updating
        do {
            try await controls.disableAutomations()
            cancelBackground()
            disableReminder()
            state = .ready
            return true
        } catch {
            state = .failed(.preferenceSaveFailed)
            return false
        }
    }
}
