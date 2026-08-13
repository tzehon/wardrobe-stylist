import Foundation
import SwiftData

/// Where an item came from.
enum ItemSource: String, Codable {
    case email
    case photo
    case manual
}

/// A single wardrobe item (garment, bag, or piece of jewelry).
extension WardrobeSchemaV1 {
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
        var imageURL: String?         // product image from the receipt (email-sourced); loaded on demand

        @Attribute(.externalStorage) var imageData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        var featurePrint: Data?       // archived VNFeaturePrintObservation for similarity/dedup

        @Relationship(deleteRule: .nullify, inverse: \WardrobeSchemaV1.WearLog.item)
        var wears: [WardrobeSchemaV1.WearLog]

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
            imageURL: String? = nil,
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
            self.imageURL = imageURL
            self.imageData = imageData
            self.thumbnailData = thumbnailData
            self.featurePrint = featurePrint
            self.wears = []
        }
    }
}

/// Current item schema. `accountSubjectKey` is populated only for Gmail-derived
/// items. A nil key on an email item means the row predates account isolation
/// and must go through the explicit legacy resolution flow before it is shown.
extension WardrobeSchemaV2 {
    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: String
        var subcategory: String?
        var brand: String?
        var colors: [String]
        var material: String?
        var styleNotes: String?
        var source: ItemSource
        var purchaseDate: Date?
        var sourceMsgId: String?
        var imageURL: String?
        var accountSubjectKey: String?

        @Attribute(.externalStorage) var imageData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        var featurePrint: Data?

        @Relationship(deleteRule: .nullify, inverse: \WardrobeSchemaV2.WearLog.item)
        var wears: [WardrobeSchemaV2.WearLog]

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
            imageURL: String? = nil,
            accountSubjectKey: String? = nil,
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
            self.imageURL = imageURL
            self.accountSubjectKey = accountSubjectKey
            self.imageData = imageData
            self.thumbnailData = thumbnailData
            self.featurePrint = featurePrint
            self.wears = []
        }
    }
}

/// Source-compatible name for the current model version.
typealias Item = WardrobeSchemaV2.Item
