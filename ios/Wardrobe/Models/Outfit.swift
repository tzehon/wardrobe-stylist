import Foundation
import SwiftData

/// A recommended or recorded combination of items.
extension WardrobeSchemaV1 {
    @Model
    final class Outfit {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var occasion: String?
        var rationale: String?
        var colorStory: String?

        @Relationship var items: [WardrobeSchemaV1.Item]

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            occasion: String? = nil,
            rationale: String? = nil,
            colorStory: String? = nil,
            items: [WardrobeSchemaV1.Item] = []
        ) {
            self.id = id
            self.createdAt = createdAt
            self.occasion = occasion
            self.rationale = rationale
            self.colorStory = colorStory
            self.items = items
        }
    }
}

extension WardrobeSchemaV2 {
    @Model
    final class Outfit {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var occasion: String?
        var rationale: String?
        var colorStory: String?
        var accountSubjectKey: String?

        @Relationship var items: [WardrobeSchemaV2.Item]

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            occasion: String? = nil,
            rationale: String? = nil,
            colorStory: String? = nil,
            accountSubjectKey: String? = nil,
            items: [WardrobeSchemaV2.Item] = []
        ) {
            self.id = id
            self.createdAt = createdAt
            self.occasion = occasion
            self.rationale = rationale
            self.colorStory = colorStory
            self.accountSubjectKey = accountSubjectKey
            self.items = items
        }
    }
}

/// Source-compatible name for the current model version.
typealias Outfit = WardrobeSchemaV2.Outfit
