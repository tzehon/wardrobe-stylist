import Foundation
import UserNotifications

/// Narrow seam over `UNUserNotificationCenter` so scheduling logic is testable
/// without the real notification server. Production uses `SystemNotificationCenter`.
protocol UserNotificationScheduling {
    /// Returns whether the user granted alert permission.
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotifications(withIdentifiers identifiers: [String])
}

/// Thin wrapper binding the protocol to the live notification center.
struct SystemNotificationCenter: UserNotificationScheduling {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePendingNotifications(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Schedules the daily "your outfit is ready" nudge. A repeating local
/// notification — the outfit itself is computed on open (`TodayView`), so this
/// never touches the network and can't fail in the background.
struct DailyOutfitNotifier {

    /// Stable id so re-scheduling replaces rather than stacks reminders.
    static let identifier = "com.tth.Wardrobe.dailyOutfit"

    /// Default fire time — 7am local, a repeating calendar trigger.
    static let defaultHour = 7

    let center: UserNotificationScheduling

    init(center: UserNotificationScheduling = SystemNotificationCenter()) {
        self.center = center
    }

    /// Pure request builder — a repeating daily calendar trigger at `hour:00`.
    static func makeRequest(hour: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Today's outfit is ready"
        content.body = "Aria has styled a look for you — tap to see it."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    /// Requests authorization (if not already granted) and (re)schedules the
    /// daily reminder. Returns `false` — without scheduling anything — when the
    /// user declines. Removing the pending request first keeps it idempotent.
    @discardableResult
    func enableDailyReminder(hour: Int = defaultHour) async throws -> Bool {
        guard try await center.requestAuthorization() else { return false }
        center.removePendingNotifications(withIdentifiers: [Self.identifier])
        try await center.add(Self.makeRequest(hour: hour))
        return true
    }
}
