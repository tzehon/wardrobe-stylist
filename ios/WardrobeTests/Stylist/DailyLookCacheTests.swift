import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct DailyLookCacheTests {
    private let accountA = WardrobeAccountScope.external(.external("account-a"))
    private let accountB = WardrobeAccountScope.external(.external("account-b"))

    @Test func cacheRoundTripsAndRemainsAccountIsolated() throws {
        try withDefaults { defaults in
            let cache = UserDefaultsDailyLookCache(defaults: defaults)
            let entry = makeEntry()

            cache.save(entry, for: accountA)

            #expect(cache.load(for: accountA) == entry)
            #expect(cache.load(for: accountB) == nil)
            cache.remove(for: accountA)
            #expect(cache.load(for: accountA) == nil)
        }
    }

    @Test func corruptAndActuallyPersistedFutureEntriesFailClosed() throws {
        try withDefaults { defaults in
            let cache = UserDefaultsDailyLookCache(defaults: defaults)

            cache.replaceRawDataForTesting(Data("not-json".utf8), for: accountA)
            #expect(cache.rawDataForTesting(for: accountA) != nil)
            #expect(cache.load(for: accountA) == nil)
            #expect(cache.rawDataForTesting(for: accountA) == nil)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let futureData = try encoder.encode(makeEntry(formatVersion: 2))
            cache.replaceRawDataForTesting(futureData, for: accountA)
            #expect(cache.rawDataForTesting(for: accountA) == futureData)
            #expect(cache.load(for: accountA) == nil)
            #expect(cache.rawDataForTesting(for: accountA) == nil)
        }
    }

    @Test func allAppOwnedPurgeClearsEveryAccountCacheButKeepsUnrelatedDefaults() throws {
        try withDefaults { defaults in
            let cache = UserDefaultsDailyLookCache(defaults: defaults)
            cache.save(makeEntry(), for: accountA)
            cache.save(makeEntry(occasion: "dinner"), for: accountB)
            defaults.set("keep", forKey: "unrelated.preference")

            #expect(cache.removeAllAppOwnedEntriesAndVerify())

            #expect(cache.load(for: accountA) == nil)
            #expect(cache.load(for: accountB) == nil)
            #expect(defaults.string(forKey: "unrelated.preference") == "keep")
        }
    }

    @Test func reuseRequiresSameDayCatalogAndNormalizedOccasion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let entry = makeEntry(occasion: "  WORK ")

        #expect(entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_000_100),
            calendar: calendar,
            catalogFingerprint: "catalog-a",
            occasion: "work"
        ))
        #expect(!entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_086_500),
            calendar: calendar,
            catalogFingerprint: "catalog-a",
            occasion: "work"
        ))
        #expect(!entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_000_100),
            calendar: calendar,
            catalogFingerprint: "catalog-b",
            occasion: "work"
        ))
        #expect(!entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_000_100),
            calendar: calendar,
            catalogFingerprint: "catalog-a",
            occasion: "dinner"
        ))
        #expect(entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_000_100),
            calendar: calendar,
            catalogFingerprint: "catalog-a",
            occasion: nil,
            acceptsStoredOccasionWhenRequestIsEmpty: true
        ))
        #expect(!entry.isReusable(
            at: Date(timeIntervalSince1970: 1_700_000_100),
            calendar: calendar,
            catalogFingerprint: "catalog-a",
            occasion: "dinner",
            acceptsStoredOccasionWhenRequestIsEmpty: true
        ))
    }

    @Test func fingerprintIsStableAcrossCatalogOrderAndSensitiveToStyleFields() {
        let first = RecommendCatalogItem(
            id: "1", name: "Shirt", category: "top", colors: ["navy"]
        )
        let second = RecommendCatalogItem(
            id: "2", name: "Trouser", category: "bottom", material: "wool"
        )
        let baseline = DailyLookCatalogFingerprint.make(from: [first, second])

        #expect(DailyLookCatalogFingerprint.make(from: [second, first]) == baseline)
        #expect(DailyLookCatalogFingerprint.make(from: [
            first,
            RecommendCatalogItem(
                id: "2", name: "Trouser", category: "bottom", material: "linen"
            ),
        ]) != baseline)
    }

    private func makeEntry(
        occasion: String? = "work",
        formatVersion: Int = DailyLookCacheEntry.currentFormatVersion
    ) -> DailyLookCacheEntry {
        DailyLookCacheEntry(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            catalogFingerprint: "catalog-a",
            occasion: occasion,
            response: RecommendResponse(
                occasion: "work",
                colorStory: "navy",
                rationale: "balanced",
                itemIds: ["1", "2"],
                alternates: [],
                usage: [:]
            ),
            formatVersion: formatVersion
        )
    }

    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suiteName = "DailyLookCacheTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try test(defaults)
    }
}
