import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct OutfitHistoryTests {
    @Test func groupsLooksNewestFirstAndBuildsLocalInsights() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let olderDate = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 10, hour: 9
        )))
        let newerDate = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 11, hour: 9
        )))
        let shirt = Item(name: "Shirt", category: "top", isFavorite: true)
        let archived = Item(name: "Old coat", category: "outerwear", isArchived: true)
        let older = Outfit(createdAt: olderDate, items: [shirt])
        let newer = Outfit(createdAt: newerDate, items: [shirt])
        let wears = [
            WearLog(item: shirt, outfit: older),
            WearLog(item: shirt, outfit: newer),
            WearLog(item: archived, outfit: older),
        ]

        let days = OutfitHistoryOrganizer.days(
            from: [older, newer], in: .deviceLocal, calendar: calendar
        )
        #expect(days.map(\.date) == [
            calendar.startOfDay(for: newerDate),
            calendar.startOfDay(for: olderDate),
        ])

        let insights = WardrobeInsights.make(
            items: [shirt, archived],
            outfits: [older, newer],
            wearLogs: wears,
            in: .deviceLocal
        )
        #expect(insights.looksWorn == 2)
        #expect(insights.piecesWorn == 1)
        #expect(insights.favorites == 1)
        #expect(insights.mostWorn.first?.wearCount == 2)
    }
}
