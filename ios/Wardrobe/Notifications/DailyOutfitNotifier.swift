import Foundation
import UserNotifications

/// Narrow seam over `UNUserNotificationCenter` so scheduling logic is testable
/// without the real notification server. Production uses `SystemNotificationCenter`.
protocol UserNotificationScheduling {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotifications(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

enum ReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Thin wrapper binding the protocol to the live notification center.
struct SystemNotificationCenter: UserNotificationScheduling {
    func authorizationStatus() async -> ReminderAuthorizationStatus {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .authorized
        @unknown default:
            .denied
        }
    }

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

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

struct DailyReminderTime: Codable, Equatable, Sendable {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    static let defaultMorning = Self(hour: 7, minute: 0)!
}

/// Schedules a truthful daily styling nudge. The outfit itself is computed only
/// after the user opens Today, so the notification never claims a look is ready.
struct DailyOutfitNotifier {

    /// Stable id so re-scheduling replaces rather than stacks reminders.
    static let identifier = "com.tth.Wardrobe.dailyOutfit"

    static let destinationKey = "destination"
    static let todayDestination = "today"

    let center: UserNotificationScheduling

    init(center: UserNotificationScheduling = SystemNotificationCenter()) {
        self.center = center
    }

    /// Pure request builder — a repeating calendar trigger in the user's local
    /// timezone with a routing payload for the Today tab.
    static func makeRequest(time: DailyReminderTime = .defaultMorning) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Ready to style your day?"
        content.body = "Open Wardrobe Stylist when you’re ready for today’s look."
        content.sound = .default
        content.userInfo = [destinationKey: todayDestination]

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    /// Called only from an explicit reminder control. Requests authorization on
    /// first use, returns false without scheduling when permission is denied,
    /// and replaces an existing request when the time changes.
    @discardableResult
    func enableDailyReminder(time: DailyReminderTime = .defaultMorning) async throws -> Bool {
        switch await center.authorizationStatus() {
        case .denied:
            return false
        case .notDetermined:
            guard try await center.requestAuthorization() else { return false }
        case .authorized:
            break
        }
        center.removePendingNotifications(withIdentifiers: [Self.identifier])
        try await center.add(Self.makeRequest(time: time))
        return true
    }

    func disableDailyReminder() {
        center.removePendingNotifications(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}
