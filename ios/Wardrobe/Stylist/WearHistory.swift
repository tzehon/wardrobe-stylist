import Foundation

/// Pure logic for "what has the user worn recently" — feeds Aria's anti-repeat.
///
/// Protocol-driven so it unit-tests without SwiftData. A wear counts toward the
/// recent window if it has an associated item and its date is on/after the cutoff.
protocol DatedWear {
    var wornItemID: UUID? { get }
    var wornDate: Date { get }
}

extension WearLog: DatedWear {
    var wornItemID: UUID? { item?.id }
    var wornDate: Date { date }
}

enum WearHistory {
    /// Default look-back window for anti-repeat.
    static let defaultWindowDays = 14

    /// Distinct item ids (as UUID strings) worn on or after `since`, most-recent first.
    static func recentlyWornIDs(from wears: [some DatedWear], since: Date) -> [String] {
        var seen: Set<UUID> = []
        var result: [String] = []
        for wear in wears.sorted(by: { $0.wornDate > $1.wornDate }) {
            guard wear.wornDate >= since, let id = wear.wornItemID else { continue }
            if seen.insert(id).inserted {
                result.append(id.uuidString)
            }
        }
        return result
    }

    /// The cutoff date for the default window, relative to `now`.
    static func cutoff(from now: Date, windowDays: Int = defaultWindowDays) -> Date {
        now.addingTimeInterval(-Double(windowDays) * 24 * 60 * 60)
    }
}
