import Foundation
import SwiftData

/// A record that an item / outfit was worn on a given day — powers anti-repetition.
@Model
final class WearLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var item: Item?
    var outfit: Outfit?
    var feedback: Int?            // optional rating, e.g. 1...5

    init(
        id: UUID = UUID(),
        date: Date = .now,
        item: Item? = nil,
        outfit: Outfit? = nil,
        feedback: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.outfit = outfit
        self.feedback = feedback
    }
}
