import Foundation
import SwiftData

/// Where an item came from.
enum ItemSource: String, Codable {
    case email
    case photo
    case manual
}

/// A single wardrobe item (garment, bag, or piece of jewelry).
@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String          // top, bottom, dress, outerwear, shoe, bag, jewelry, accessory
    var subcategory: String?
    var brand: String?
    var colors: [String]          // hex or names extracted on-device (Vision)
    var material: String?
    var styleNotes: String?
    var source: ItemSource
    var purchaseDate: Date?
    var sourceMsgId: String?      // Gmail message id (audit trail; email-sourced items)

    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var featurePrint: Data?       // archived VNFeaturePrintObservation for similarity/dedup

    @Relationship(deleteRule: .nullify, inverse: \WearLog.item) var wears: [WearLog]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        subcategory: String? = nil,
        brand: String? = nil,
        colors: [String] = [],
        material: String? = nil,
        styleNotes: String? = nil,
        source: ItemSource = .manual,
        purchaseDate: Date? = nil,
        sourceMsgId: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        featurePrint: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.colors = colors
        self.material = material
        self.styleNotes = styleNotes
        self.source = source
        self.purchaseDate = purchaseDate
        self.sourceMsgId = sourceMsgId
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.featurePrint = featurePrint
        self.wears = []
    }
}
