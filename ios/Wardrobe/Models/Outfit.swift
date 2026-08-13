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

        @Relationship var items: [Item]

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            occasion: String? = nil,
            rationale: String? = nil,
            colorStory: String? = nil,
            items: [Item] = []
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

/// Source-compatible name for the current model version.
typealias Outfit = WardrobeSchemaV1.Outfit
