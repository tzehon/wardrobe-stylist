import Foundation

/// Presentation-ready history grouped by the day a look was recorded. Keeping
/// organization pure makes ordering and empty-item edge
/// cases independently testable from SwiftUI/SwiftData.
struct OutfitHistoryDay: Identifiable {
    let date: Date
    let outfits: [Outfit]

    var id: Date { date }
}

struct WardrobeInsightsSnapshot {
    struct RankedItem: Identifiable {
        let item: Item
        let wearCount: Int
        var id: UUID { item.id }
    }

    let looksWorn: Int
    let piecesWorn: Int
    let unwornPieces: Int
    let favorites: Int
    let mostWorn: [RankedItem]
}

enum OutfitHistoryOrganizer {
    static func days(
        from outfits: [Outfit],
        in accountScope: WardrobeAccountScope,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [OutfitHistoryDay] {
        let visible = WardrobeAccountFilter.visibleOutfits(
            from: outfits,
            in: accountScope
        )
        let grouped = Dictionary(grouping: visible) { outfit in
            calendar.startOfDay(for: outfit.createdAt)
        }
        return grouped
            .map { day, outfits in
                OutfitHistoryDay(
                    date: day,
                    outfits: outfits.sorted {
                        if $0.createdAt != $1.createdAt {
                            return $0.createdAt > $1.createdAt
                        }
                        return $0.id.uuidString < $1.id.uuidString
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }
}

enum WardrobeInsights {
    static func make(
        items: [Item],
        outfits: [Outfit],
        wearLogs: [WearLog],
        in accountScope: WardrobeAccountScope
    ) -> WardrobeInsightsSnapshot {
        let activeItems = WardrobeAccountFilter.visibleItems(from: items, in: accountScope)
            .filter { !$0.isArchived }
        let activeIDs = Set(activeItems.map(\.id))
        let visibleWears = WardrobeAccountFilter.visibleWearLogs(
            from: wearLogs,
            in: accountScope
        )

        var counts: [UUID: Int] = [:]
        for wear in visibleWears {
            guard let itemID = wear.item?.id, activeIDs.contains(itemID) else { continue }
            counts[itemID, default: 0] += 1
        }

        let ranked = activeItems.compactMap { item -> WardrobeInsightsSnapshot.RankedItem? in
            guard let count = counts[item.id], count > 0 else { return nil }
            return WardrobeInsightsSnapshot.RankedItem(item: item, wearCount: count)
        }
        .sorted { lhs, rhs in
            if lhs.wearCount != rhs.wearCount { return lhs.wearCount > rhs.wearCount }
            let nameOrder = lhs.item.name.localizedCaseInsensitiveCompare(rhs.item.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.item.id.uuidString < rhs.item.id.uuidString
        }

        return WardrobeInsightsSnapshot(
            looksWorn: WardrobeAccountFilter.visibleOutfits(
                from: outfits,
                in: accountScope
            ).count,
            piecesWorn: counts.count,
            unwornPieces: max(0, activeItems.count - counts.count),
            favorites: activeItems.lazy.filter(\.isFavorite).count,
            mostWorn: Array(ranked.prefix(3))
        )
    }
}
