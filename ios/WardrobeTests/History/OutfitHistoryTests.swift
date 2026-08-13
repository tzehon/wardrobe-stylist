import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct OutfitHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test func groupsVisibleLooksNewestDayAndTimeFirst() throws {
        let scope = WardrobeAccountScope.deviceLocal
        let other = WardrobeAccountScope.external(.external("history-other"))
        let first = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 10, hour: 9
        )))
        let second = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 10, hour: 18
        )))
        let newest = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12, hour: 7
        )))
        let older = Outfit(createdAt: first, accountSubjectKey: scope.rawValue)
        let laterSameDay = Outfit(createdAt: second, accountSubjectKey: scope.rawValue)
        let newestDay = Outfit(createdAt: newest, accountSubjectKey: scope.rawValue)
        let hidden = Outfit(createdAt: newest.addingTimeInterval(60), accountSubjectKey: other.rawValue)

        let days = OutfitHistoryOrganizer.days(
            from: [older, hidden, newestDay, laterSameDay],
            in: scope,
            calendar: calendar
        )

        #expect(days.count == 2)
        #expect(days.map(\.date) == [
            calendar.startOfDay(for: newest),
            calendar.startOfDay(for: first),
        ])
        #expect(days[0].outfits.map(\.id) == [newestDay.id])
        #expect(days[1].outfits.map(\.id) == [laterSameDay.id, older.id])
    }

    @Test func legacyAndOtherAccountLooksStayHidden() {
        let scopeA = WardrobeAccountScope.external(.external("history-a"))
        let scopeB = WardrobeAccountScope.external(.external("history-b"))
        let a = Outfit(accountSubjectKey: scopeA.rawValue)
        let b = Outfit(accountSubjectKey: scopeB.rawValue)
        let legacy = Outfit(accountSubjectKey: nil)

        let days = OutfitHistoryOrganizer.days(
            from: [legacy, b, a],
            in: scopeA,
            calendar: calendar
        )

        #expect(days.flatMap(\.outfits).map(\.id) == [a.id])
    }

    @Test func emptyInputProducesNoSections() {
        #expect(OutfitHistoryOrganizer.days(
            from: [],
            in: .deviceLocal,
            calendar: calendar
        ).isEmpty)
    }

    @Test func insightsAreLocalAccountScopedAndExcludePendingOrArchivedPieces() {
        let scopeA = WardrobeAccountScope.external(.external("insights-a"))
        let scopeB = WardrobeAccountScope.external(.external("insights-b"))
        let favorite = Item(name: "Favorite shirt", category: "top", isFavorite: true)
        let trousers = Item(name: "Trousers", category: "bottom")
        let pending = Item(
            name: "Pending",
            category: "shoe",
            source: .email,
            accountSubjectKey: scopeA.rawValue,
            reviewState: .pendingReview
        )
        let archived = Item(name: "Archived", category: "bag", isArchived: true)
        let foreign = Item(
            name: "Other account",
            category: "dress",
            source: .email,
            accountSubjectKey: scopeB.rawValue
        )
        let outfitA = Outfit(accountSubjectKey: scopeA.rawValue, items: [favorite, trousers])
        let outfitB = Outfit(accountSubjectKey: scopeB.rawValue, items: [foreign])
        let wears = [
            WearLog(item: favorite, outfit: outfitA, accountSubjectKey: scopeA.rawValue),
            WearLog(item: favorite, outfit: outfitA, accountSubjectKey: scopeA.rawValue),
            WearLog(item: archived, outfit: outfitA, accountSubjectKey: scopeA.rawValue),
            WearLog(item: foreign, outfit: outfitB, accountSubjectKey: scopeB.rawValue),
        ]

        let snapshot = WardrobeInsights.make(
            items: [favorite, trousers, pending, archived, foreign],
            outfits: [outfitA, outfitB],
            wearLogs: wears,
            in: scopeA
        )

        #expect(snapshot.looksWorn == 1)
        #expect(snapshot.piecesWorn == 1)
        #expect(snapshot.unwornPieces == 1)
        #expect(snapshot.favorites == 1)
        #expect(snapshot.mostWorn.map(\.item.id) == [favorite.id])
        #expect(snapshot.mostWorn.map(\.wearCount) == [2])
    }
}
