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
    typealias MainAction = @MainActor @Sendable () -> Void
    typealias PresentationCompletion =
        @MainActor @Sendable (UNNotificationPresentationOptions) -> Void

    static let shared = DailyReminderNotificationRouter()

    private let recordTodayDestination: MainAction
    private let publishTodayDestination: MainAction

    override init() {
        recordTodayDestination = {
            UserDefaultsAppNavigationSignalStore().recordTodayDestination()
        }
        publishTodayDestination = {
            NotificationCenter.default.post(
                name: .wardrobeNavigateToToday,
                object: nil
            )
        }
        super.init()
    }

    init(
        recordTodayDestination: @escaping MainAction,
        publishTodayDestination: @escaping MainAction
    ) {
        self.recordTodayDestination = recordTodayDestination
        self.publishTodayDestination = publishTodayDestination
        super.init()
    }

    @MainActor
    func install(center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let fields = DailyReminderResponseFields(
            request: response.notification.request,
            actionIdentifier: response.actionIdentifier
        )
        let completion: MainAction = { completionHandler() }
        handle(fields, completion: completion)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        let completion: PresentationCompletion = { options in
            completionHandler(options)
        }
        present(completion: completion)
    }

    /// Explicit main-queue seam for foreground presentation responses.
    nonisolated func present(completion: @escaping PresentationCompletion) {
        // This also removes the second imported async delegate bridge from the
        // notification router.
        DispatchQueue.main.async { @MainActor in
            completion([.banner, .sound])
        }
    }

    /// Testable response seam. The durable bit is written before the live event
    /// so a cold launch cannot lose the route. UIKit's completion is kept in a
    /// single `defer`, guaranteeing one call for accepted and ignored taps.
    nonisolated func handle(
        _ fields: DailyReminderResponseFields,
        completion: @escaping MainAction
    ) {
        let shouldOpenToday = DailyReminderNavigation.shouldOpenToday(fields)
        let recordTodayDestination = recordTodayDestination
        let publishTodayDestination = publishTodayDestination

        // Do not use the imported async delegate requirement here. Its
        // generated Objective-C bridge can resume on a cooperative executor
        // and invoke UIKit's completion block off the main thread. A physical
        // TestFlight notification tap proved that path aborts while UIKit is
        // updating state restoration. Queue routing and completion explicitly.
        DispatchQueue.main.async { @MainActor in
            defer { completion() }
            guard shouldOpenToday else { return }
            recordTodayDestination()
            publishTodayDestination()
        }
    }
}
