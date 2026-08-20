import Foundation
import SwiftData

/// A device-local wear record used to avoid repetitive recommendations.
@Model
final class WearLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var item: Item?
    var outfit: Outfit?
    var feedback: Int?

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
