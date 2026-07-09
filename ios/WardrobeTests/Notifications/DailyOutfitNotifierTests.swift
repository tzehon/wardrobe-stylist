import Foundation
import Testing
import UserNotifications

@testable import Wardrobe

struct DailyOutfitNotifierTests {

    private struct StubError: Error {}

    private final class FakeCenter: UserNotificationScheduling {
        var authorizationGranted = true
        var authorizationError: Error?
        var added: [UNNotificationRequest] = []
        var removedIdentifiers: [String] = []

        func requestAuthorization() async throws -> Bool {
            if let authorizationError { throw authorizationError }
            return authorizationGranted
        }

        func add(_ request: UNNotificationRequest) async throws {
            added.append(request)
        }

        func removePendingNotifications(withIdentifiers identifiers: [String]) {
            removedIdentifiers.append(contentsOf: identifiers)
        }
    }

    @Test func requestIsARepeatingDailyReminderAtGivenHour() throws {
        let request = DailyOutfitNotifier.makeRequest(hour: 7)

        #expect(request.identifier == DailyOutfitNotifier.identifier)
        #expect(request.content.title == "Today's outfit is ready")
        #expect(request.content.body.contains("Aria"))

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func enableSchedulesOnceWhenAuthorized() async throws {
        let center = FakeCenter()
        let notifier = DailyOutfitNotifier(center: center)

        let scheduled = try await notifier.enableDailyReminder(hour: 8)

        #expect(scheduled)
        #expect(center.added.count == 1)
        #expect(center.added.first?.identifier == DailyOutfitNotifier.identifier)
        // Clears the prior pending reminder first so it doesn't stack.
        #expect(center.removedIdentifiers == [DailyOutfitNotifier.identifier])
        let trigger = center.added.first?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 8)
    }

    @Test func enableSchedulesNothingWhenDeclined() async throws {
        let center = FakeCenter()
        center.authorizationGranted = false
        let notifier = DailyOutfitNotifier(center: center)

        let scheduled = try await notifier.enableDailyReminder()

        #expect(scheduled == false)
        #expect(center.added.isEmpty)
        #expect(center.removedIdentifiers.isEmpty)
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
}
