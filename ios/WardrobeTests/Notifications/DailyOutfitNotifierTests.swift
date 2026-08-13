import Foundation
import Testing
import UserNotifications

@testable import Wardrobe

struct DailyOutfitNotifierTests {

    private struct StubError: Error {}

    private final class FakeCenter: UserNotificationScheduling {
        var status: ReminderAuthorizationStatus = .notDetermined
        var authorizationGranted = true
        var authorizationError: Error?
        var authorizationRequests = 0
        var added: [UNNotificationRequest] = []
        var removedPendingIdentifiers: [String] = []
        var removedDeliveredIdentifiers: [String] = []

        func authorizationStatus() async -> ReminderAuthorizationStatus { status }

        func requestAuthorization() async throws -> Bool {
            authorizationRequests += 1
            if let authorizationError { throw authorizationError }
            return authorizationGranted
        }

        func add(_ request: UNNotificationRequest) async throws {
            added.append(request)
        }

        func removePendingNotifications(withIdentifiers identifiers: [String]) {
            removedPendingIdentifiers.append(contentsOf: identifiers)
        }

        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
            removedDeliveredIdentifiers.append(contentsOf: identifiers)
        }
    }

    @Test func requestIsTruthfulRepeatingAndRoutesToToday() throws {
        let time = try #require(DailyReminderTime(hour: 7, minute: 30))
        let request = DailyOutfitNotifier.makeRequest(time: time)

        #expect(request.identifier == DailyOutfitNotifier.identifier)
        #expect(request.content.title == "Ready to style your day?")
        #expect(request.content.title != "Today's outfit is ready")
        #expect(!request.content.body.localizedCaseInsensitiveContains("styled a look"))
        #expect(request.content.userInfo[DailyOutfitNotifier.destinationKey] as? String
                == DailyOutfitNotifier.todayDestination)

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 30)
    }

    @Test func timeRejectsInvalidClockValues() {
        #expect(DailyReminderTime(hour: -1, minute: 0) == nil)
        #expect(DailyReminderTime(hour: 24, minute: 0) == nil)
        #expect(DailyReminderTime(hour: 7, minute: 60) == nil)
    }

    @Test func enableRequestsPermissionThenSchedulesOnce() async throws {
        let center = FakeCenter()
        let notifier = DailyOutfitNotifier(center: center)
        let time = try #require(DailyReminderTime(hour: 8, minute: 15))

        let scheduled = try await notifier.enableDailyReminder(time: time)

        #expect(scheduled)
        #expect(center.authorizationRequests == 1)
        #expect(center.added.count == 1)
        #expect(center.added.first?.identifier == DailyOutfitNotifier.identifier)
        // Clears the prior pending reminder first so it doesn't stack.
        #expect(center.removedPendingIdentifiers == [DailyOutfitNotifier.identifier])
        let trigger = center.added.first?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 8)
        #expect(trigger?.dateComponents.minute == 15)
    }

    @Test func enableDoesNotRepromptWhenAlreadyAuthorized() async throws {
        let center = FakeCenter()
        center.status = .authorized
        let notifier = DailyOutfitNotifier(center: center)

        #expect(try await notifier.enableDailyReminder())
        #expect(center.authorizationRequests == 0)
        #expect(center.added.count == 1)
    }

    @Test func enableSchedulesNothingWhenDeclined() async throws {
        let center = FakeCenter()
        center.authorizationGranted = false
        let notifier = DailyOutfitNotifier(center: center)

        let scheduled = try await notifier.enableDailyReminder()

        #expect(scheduled == false)
        #expect(center.added.isEmpty)
        #expect(center.removedPendingIdentifiers.isEmpty)
    }

    @Test func enableSchedulesNothingAndDoesNotRepromptWhenAlreadyDenied() async throws {
        let center = FakeCenter()
        center.status = .denied
        let notifier = DailyOutfitNotifier(center: center)

        #expect(try await notifier.enableDailyReminder() == false)
        #expect(center.authorizationRequests == 0)
        #expect(center.added.isEmpty)
    }

    @Test func enablePropagatesAuthorizationError() async {
        let center = FakeCenter()
        center.authorizationError = StubError()
        let notifier = DailyOutfitNotifier(center: center)

        await #expect(throws: StubError.self) {
            try await notifier.enableDailyReminder()
        }
        #expect(center.added.isEmpty)
    }

    @Test func disableRemovesPendingAndDeliveredReminder() {
        let center = FakeCenter()

        DailyOutfitNotifier(center: center).disableDailyReminder()

        #expect(center.removedPendingIdentifiers == [DailyOutfitNotifier.identifier])
        #expect(center.removedDeliveredIdentifiers == [DailyOutfitNotifier.identifier])
    }
}
