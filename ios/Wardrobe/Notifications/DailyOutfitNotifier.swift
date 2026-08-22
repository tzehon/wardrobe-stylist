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

struct DailyReminderTime: Codable, Equatable, Sendable, Hashable {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    static let defaultMorning = Self(hour: 7, minute: 0)!

    /// Locale-aware text for Settings and confirmation copy.
    func formatted(locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard let date = calendar.date(from: DateComponents(hour: hour, minute: minute)) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        )
    }
}

/// Durable, device-local reminder clock. The enabled bit remains in the
/// versioned privacy preferences; storing the chosen time separately keeps a
/// reschedule from changing consent semantics.
@MainActor
protocol DailyReminderTimeStoring {
    func load() -> DailyReminderTime
    func save(_ time: DailyReminderTime) -> Bool
    func remove() -> Bool
}

@MainActor
final class UserDefaultsDailyReminderTimeStore: DailyReminderTimeStoring {
    static let storageKey = "com.tth.Wardrobe.dailyReminderTime.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DailyReminderTime {
        guard let data = defaults.data(forKey: Self.storageKey),
              let time = try? JSONDecoder().decode(DailyReminderTime.self, from: data) else {
            return .defaultMorning
        }
        return time
    }

    func save(_ time: DailyReminderTime) -> Bool {
        guard let data = try? JSONEncoder().encode(time) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return load() == time
    }

    func remove() -> Bool {
        defaults.removeObject(forKey: Self.storageKey)
        return defaults.object(forKey: Self.storageKey) == nil
    }

    func removeAndVerify() -> Bool {
        remove()
    }
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
    /// and atomically replaces the stable-identifier request when the time
    /// changes. `UNUserNotificationCenter.add` replaces a matching identifier;
    /// there is intentionally no remove-before-add window that could lose the
    /// user's existing reminder if scheduling fails.
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
        try await center.add(Self.makeRequest(time: time))
        return true
    }

    func disableDailyReminder() {
        center.removePendingNotifications(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

/// A durable navigation signal lets a notification response received during
/// cold launch survive until the tab shell is ready to consume it.
@MainActor
protocol AppNavigationSignalStoring {
    func recordTodayDestination()
    func consumeTodayDestination() -> Bool
    func clear()
}

@MainActor
final class UserDefaultsAppNavigationSignalStore: AppNavigationSignalStoring {
    static let todaySignalKey = "com.tth.Wardrobe.navigation.today.pending.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordTodayDestination() {
        defaults.set(true, forKey: Self.todaySignalKey)
    }

    func consumeTodayDestination() -> Bool {
        let isPending = defaults.bool(forKey: Self.todaySignalKey)
        if isPending { defaults.removeObject(forKey: Self.todaySignalKey) }
        return isPending
    }

    func clear() {
        defaults.removeObject(forKey: Self.todaySignalKey)
    }

    func clearAndVerify() -> Bool {
        clear()
        return defaults.object(forKey: Self.todaySignalKey) == nil
    }
}

enum DailyReminderNavigation {
    static func isTodayDestination(userInfo: [AnyHashable: Any]) -> Bool {
        userInfo[DailyOutfitNotifier.destinationKey] as? String
            == DailyOutfitNotifier.todayDestination
    }

    static func shouldOpenToday(_ fields: DailyReminderResponseFields) -> Bool {
        fields.requestIdentifier == DailyOutfitNotifier.identifier
            && fields.actionIdentifier == UNNotificationDefaultActionIdentifier
            && fields.destination == DailyOutfitNotifier.todayDestination
    }
}

/// Sendable snapshot of the only notification-response fields used for
/// routing. `UNNotificationResponse` and its `userInfo` dictionary never cross
/// the explicit hop to the main queue.
struct DailyReminderResponseFields: Equatable, Sendable {
    let requestIdentifier: String
    let actionIdentifier: String
    let destination: String?

    init(request: UNNotificationRequest, actionIdentifier: String) {
        requestIdentifier = request.identifier
        self.actionIdentifier = actionIdentifier
        destination = request.content.userInfo[DailyOutfitNotifier.destinationKey] as? String
    }
}
