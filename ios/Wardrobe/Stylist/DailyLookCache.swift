import CryptoKit
import Foundation

struct DailyLookCacheEntry: Codable, Equatable, Sendable {
    // v2 replaces the free-form usage dictionary with the exact typed wire
    // contract. Older entries are intentionally purged rather than migrated.
    static let currentFormatVersion = 2

    let formatVersion: Int
    let generatedAt: Date
    let catalogFingerprint: String
    let occasionKey: String?
    let response: RecommendResponse

    init(
        generatedAt: Date,
        catalogFingerprint: String,
        occasion: String?,
        response: RecommendResponse,
        formatVersion: Int = Self.currentFormatVersion
    ) {
        self.formatVersion = formatVersion
        self.generatedAt = generatedAt
        self.catalogFingerprint = catalogFingerprint
        self.occasionKey = Self.normalizedOccasion(occasion)
        self.response = response
    }

    func isReusable(
        at date: Date,
        calendar: Calendar,
        catalogFingerprint: String,
        occasion: String?,
        acceptsStoredOccasionWhenRequestIsEmpty: Bool = false
    ) -> Bool {
        let requestedOccasion = Self.normalizedOccasion(occasion)
        let occasionMatches = occasionKey == requestedOccasion
            || (acceptsStoredOccasionWhenRequestIsEmpty && requestedOccasion == nil)
        return formatVersion == Self.currentFormatVersion
            && calendar.isDate(generatedAt, inSameDayAs: date)
            && self.catalogFingerprint == catalogFingerprint
            && occasionMatches
    }

    static func normalizedOccasion(_ value: String?) -> String? {
        StylingOccasion.requestValue(value)?.lowercased()
    }
}

@MainActor
protocol DailyLookCaching {
    func load(for accountScope: WardrobeAccountScope) -> DailyLookCacheEntry?
    func save(_ entry: DailyLookCacheEntry, for accountScope: WardrobeAccountScope)
    func remove(for accountScope: WardrobeAccountScope)
}

/// Default seam for callers that do not own a durable cache. The production
/// Today screen explicitly injects `UserDefaultsDailyLookCache`.
@MainActor
struct DisabledDailyLookCache: DailyLookCaching {
    func load(for accountScope: WardrobeAccountScope) -> DailyLookCacheEntry? { nil }
    func save(_ entry: DailyLookCacheEntry, for accountScope: WardrobeAccountScope) {}
    func remove(for accountScope: WardrobeAccountScope) {}
}

/// Stores one small text-only recommendation for the device-local wardrobe.
/// No photos or purchase metadata enter this cache.
@MainActor
final class UserDefaultsDailyLookCache: DailyLookCaching {
    static let keyPrefix = "com.tth.Wardrobe.dailyLook.v1."

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func load(for accountScope: WardrobeAccountScope) -> DailyLookCacheEntry? {
        let key = cacheKey(for: accountScope)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let entry = try? decoder.decode(DailyLookCacheEntry.self, from: data),
              entry.formatVersion == DailyLookCacheEntry.currentFormatVersion else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return entry
    }

    func save(_ entry: DailyLookCacheEntry, for accountScope: WardrobeAccountScope) {
        guard entry.formatVersion == DailyLookCacheEntry.currentFormatVersion,
              let data = try? encoder.encode(entry) else {
            return
        }
        defaults.set(data, forKey: cacheKey(for: accountScope))
    }

    func remove(for accountScope: WardrobeAccountScope) {
        defaults.removeObject(forKey: cacheKey(for: accountScope))
    }

    func removeAndVerify(for accountScope: WardrobeAccountScope) -> Bool {
        let key = cacheKey(for: accountScope)
        defaults.removeObject(forKey: key)
        return defaults.object(forKey: key) == nil
    }

    /// Purges cached looks for current and signed-out accounts without needing
    /// to reverse their hashed scope keys. Unrelated UserDefaults remain.
    func removeAllAppOwnedEntriesAndVerify() -> Bool {
        let keys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(Self.keyPrefix)
        }
        for key in keys { defaults.removeObject(forKey: key) }
        return defaults.dictionaryRepresentation().keys.contains {
            $0.hasPrefix(Self.keyPrefix)
        } == false
    }

#if DEBUG
    func replaceRawDataForTesting(_ data: Data?, for accountScope: WardrobeAccountScope) {
        let key = cacheKey(for: accountScope)
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func rawDataForTesting(for accountScope: WardrobeAccountScope) -> Data? {
        defaults.data(forKey: cacheKey(for: accountScope))
    }
#endif

    private func cacheKey(for accountScope: WardrobeAccountScope) -> String {
        let digest = SHA256.hash(data: Data(accountScope.rawValue.utf8))
        return Self.keyPrefix + digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum DailyLookCatalogFingerprint {
    static func make(from items: [RecommendCatalogItem]) -> String {
        let canonical = items
            .sorted { $0.id < $1.id }
            .map { item in
                [
                    item.id,
                    item.name,
                    item.category,
                    item.brand ?? "",
                    item.colors.joined(separator: "\u{1E}"),
                    item.material ?? "",
                ].map(lengthPrefixed).joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1D}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func lengthPrefixed(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }
}
