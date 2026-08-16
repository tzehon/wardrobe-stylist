import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    static let wardrobeNavigateToToday = Notification.Name(
        "com.tth.Wardrobe.navigation.navigateToToday"
    )
}

/// Installs as the notification-center delegate without asking permission.
/// Tapping the exact reminder payload records a durable cold-launch signal and
/// broadcasts a live signal for an already-running tab shell.
final class DailyReminderNotificationRouter: NSObject, UNUserNotificationCenterDelegate,
    @unchecked Sendable {
    static let shared = DailyReminderNotificationRouter()

    @MainActor
    func install(center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo[DailyOutfitNotifier.destinationKey] as? String
                == DailyOutfitNotifier.todayDestination else { return }

        await MainActor.run {
            UserDefaultsAppNavigationSignalStore().recordTodayDestination()
            NotificationCenter.default.post(name: .wardrobeNavigateToToday, object: nil)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
