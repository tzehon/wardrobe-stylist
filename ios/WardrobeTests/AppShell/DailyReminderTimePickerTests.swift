import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct DailyReminderTimePickerTests {
    @Test func dateRoundTripUsesTheProvidedCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 8 * 60 * 60))
        let expected = try #require(DailyReminderTime(hour: 22, minute: 35))

        let date = DailyReminderTimePicker.date(for: expected, calendar: calendar)

        #expect(DailyReminderTimePicker.time(from: date, calendar: calendar) == expected)
    }
}
