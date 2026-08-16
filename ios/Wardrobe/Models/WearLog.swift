import Foundation
import SwiftData

/// A record that an item / outfit was worn on a given day — powers anti-repetition.
extension WardrobeSchemaV1 {
    @Model
    final class WearLog {
        @Attribute(.unique) var id: UUID
        var date: Date
        var item: WardrobeSchemaV1.Item?
        var outfit: WardrobeSchemaV1.Outfit?
        var feedback: Int?            // optional rating, e.g. 1...5

        init(
            id: UUID = UUID(),
            date: Date = .now,
            item: WardrobeSchemaV1.Item? = nil,
            outfit: WardrobeSchemaV1.Outfit? = nil,
            feedback: Int? = nil
        ) {
            self.id = id
            self.date = date
            self.item = item
            self.outfit = outfit
            self.feedback = feedback
        }
    }
}

extension WardrobeSchemaV2 {
    @Model
    final class WearLog {
        @Attribute(.unique) var id: UUID
        var date: Date
        var item: WardrobeSchemaV2.Item?
        var outfit: WardrobeSchemaV2.Outfit?
        var feedback: Int?
        var accountSubjectKey: String?

        init(
            id: UUID = UUID(),
            date: Date = .now,
            item: WardrobeSchemaV2.Item? = nil,
            outfit: WardrobeSchemaV2.Outfit? = nil,
            feedback: Int? = nil,
            accountSubjectKey: String? = nil
        ) {
            self.id = id
            self.date = date
            self.item = item
            self.outfit = outfit
            self.feedback = feedback
            self.accountSubjectKey = accountSubjectKey
        }
    }
}

extension WardrobeSchemaV3 {
    @Model
    final class WearLog {
        @Attribute(.unique) var id: UUID
        var date: Date
        var item: WardrobeSchemaV3.Item?
        var outfit: WardrobeSchemaV3.Outfit?
        var feedback: Int?
        var accountSubjectKey: String?

        init(
            id: UUID = UUID(),
            date: Date = .now,
            item: WardrobeSchemaV3.Item? = nil,
            outfit: WardrobeSchemaV3.Outfit? = nil,
            feedback: Int? = nil,
            accountSubjectKey: String? = nil
        ) {
            self.id = id
            self.date = date
            self.item = item
            self.outfit = outfit
            self.feedback = feedback
            self.accountSubjectKey = accountSubjectKey
        }
    }
}

/// Source-compatible name for the current model version.
typealias WearLog = WardrobeSchemaV3.WearLog
