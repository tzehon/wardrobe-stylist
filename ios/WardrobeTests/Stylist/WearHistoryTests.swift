import Foundation
import Testing

@testable import Wardrobe

struct WearHistoryTests {

    private struct StubWear: DatedWear {
        let wornItemID: UUID?
        let wornDate: Date
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func includesWearsInsideWindowAndExcludesOlder() {
        let cutoff = WearHistory.cutoff(from: now)  // now - 14d
        let recent = UUID()
        let old = UUID()
        let wears = [
            StubWear(wornItemID: recent, wornDate: now.addingTimeInterval(-2 * 86_400)),
            StubWear(wornItemID: old, wornDate: now.addingTimeInterval(-30 * 86_400)),
        ]
        let ids = WearHistory.recentlyWornIDs(from: wears, since: cutoff)
        #expect(ids == [recent.uuidString])
    }

    @Test func dedupesAndOrdersMostRecentFirst() {
        let a = UUID()
        let b = UUID()
        let wears = [
            StubWear(wornItemID: a, wornDate: now.addingTimeInterval(-5 * 86_400)),
            StubWear(wornItemID: b, wornDate: now.addingTimeInterval(-1 * 86_400)),
            StubWear(wornItemID: a, wornDate: now.addingTimeInterval(-3 * 86_400)),  // dup, newer
        ]
        let ids = WearHistory.recentlyWornIDs(from: wears, since: WearHistory.cutoff(from: now))
        // b worn most recently (1d), then a's most-recent wear (3d).
        #expect(ids == [b.uuidString, a.uuidString])
    }

    @Test func skipsWearsWithNoItem() {
        let wears = [
            StubWear(wornItemID: nil, wornDate: now.addingTimeInterval(-1 * 86_400)),
        ]
        #expect(WearHistory.recentlyWornIDs(from: wears, since: WearHistory.cutoff(from: now)).isEmpty)
    }

    @Test func cutoffIsWindowDaysBeforeNow() {
        let cutoff = WearHistory.cutoff(from: now, windowDays: 7)
        #expect(cutoff == now.addingTimeInterval(-7 * 86_400))
    }

    @MainActor
    @Test func aggregatesValidRatingsByItemInStableOrder() {
        let itemB = Item(id: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!, name: "B", category: "top")
        let itemA = Item(id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!, name: "A", category: "bottom")
        let preferences = WearHistory.itemPreferences(from: [
            WearLog(item: itemB, feedback: 5),
            WearLog(item: itemA, feedback: 2),
            WearLog(item: itemA, feedback: 4),
            WearLog(item: itemA, feedback: nil),
            WearLog(item: itemB, feedback: 8),
        ])

        #expect(preferences == [
            RecommendItemPreference(id: itemA.id.uuidString, averageRating: 3, ratingCount: 2),
            RecommendItemPreference(id: itemB.id.uuidString, averageRating: 5, ratingCount: 1),
        ])
    }
}
