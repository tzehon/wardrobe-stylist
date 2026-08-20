import Foundation
import SwiftData

enum ItemSource: String, Codable, Sendable {
    case photo
    case manual
}

/// A device-local wardrobe item created directly by the user.
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
    var size: String?
    var source: ItemSource
    var purchaseDate: Date?
    var purchasePrice: Double?
    var purchaseCurrency: String?
    var possibleDuplicateOfItemID: UUID?
    var isFavorite: Bool
    var isArchived: Bool

    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var featurePrint: Data?

    @Relationship(deleteRule: .nullify, inverse: \WearLog.item)
    var wears: [WearLog]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        subcategory: String? = nil,
        brand: String? = nil,
        colors: [String] = [],
        size: String? = nil,
        material: String? = nil,
        styleNotes: String? = nil,
        source: ItemSource = .manual,
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        purchaseCurrency: String? = nil,
        possibleDuplicateOfItemID: UUID? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
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
        self.size = size
        self.material = material
        self.styleNotes = styleNotes
        self.source = source
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.purchaseCurrency = purchaseCurrency
        self.possibleDuplicateOfItemID = possibleDuplicateOfItemID
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.featurePrint = featurePrint
        self.wears = []
    }
}
