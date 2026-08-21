import Foundation

/// Wire types for `POST /recommend` on the Wardrobe backend (Phase 5, "Aria").
/// Property names are Swift-camelCase; JSONEncoder/JSONDecoder is configured with
/// snake_case strategies so the wire format matches the backend's Pydantic models
/// (`shared/schemas/outfit.schema.json` is the contract for the response).

/// One catalog item, compacted to the minimum Aria needs to style — no images,
/// no purchase metadata. Ids are the SwiftData `Item.id` (UUID) as a string.
enum RecommendContractLimits {
    static let minimumItems = 2
    static let maximumItems = 1_000
    static let maximumItemIDLength = 64
    static let maximumNameLength = 256
    static let maximumCategoryLength = 64
    static let maximumBrandLength = 128
    static let maximumColors = 16
    static let maximumMaterialLength = 128
    static let maximumRecentlyWornIDs = 1_000
    static let maximumItemPreferences = 1_000
    static let maximumOccasionLength = 128

    static func codePointCount(_ value: String) -> Int {
        value.unicodeScalars.count
    }

    static func isWithin(_ value: String, maximum: Int) -> Bool {
        codePointCount(value) <= maximum
    }
}

enum RecommendRequestValidationIssue: Error, Equatable, Sendable {
    enum CatalogField: String, Equatable, Sendable {
        case id
        case name
        case category
        case brand
        case material
    }

    case itemCount(Int)
    case emptyCatalogField(CatalogField)
    case catalogFieldTooLong(CatalogField)
    case tooManyColors
    case tooManyRecentlyWornIDs
    case tooManyItemPreferences
    case invalidCatalogReference
    case invalidItemPreference
    case occasionTooLong

    var recoveryMessage: String {
        switch self {
        case .itemCount(let count) where count > RecommendContractLimits.maximumItems:
            let excess = count - RecommendContractLimits.maximumItems
            return "Aria can style up to 1,000 active items. Archive at least \(excess) item\(excess == 1 ? "" : "s") in Catalog, then try again."
        case .itemCount:
            return "Add at least two active items in Catalog, then try styling again."
        case .emptyCatalogField(let field):
            return "One active item has no \(field.rawValue). Edit it in Catalog, then try again."
        case .catalogFieldTooLong(let field):
            return "One active item’s \(field.rawValue) is too long for secure styling. Shorten it in Catalog, then try again."
        case .tooManyColors:
            return "One active item has more than 16 colors. Edit its colors in Catalog, then try again."
        case .tooManyRecentlyWornIDs, .tooManyItemPreferences:
            return "Wardrobe couldn’t safely prepare your local styling history. Archive some items and try again."
        case .invalidCatalogReference, .invalidItemPreference, .occasionTooLong:
            return "Wardrobe couldn’t safely prepare this styling request. Review your Catalog details and try again."
        }
    }
}

struct RecommendCatalogItem: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let category: String
    let brand: String?
    let colors: [String]
    let material: String?

    init(
        id: String,
        name: String,
        category: String,
        brand: String? = nil,
        colors: [String] = [],
        material: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brand = brand
        self.colors = colors
        self.material = material
    }
}

struct RecommendRequest: Codable, Sendable, Equatable {
    let items: [RecommendCatalogItem]
    let recentlyWornIds: [String]
    let itemPreferences: [RecommendItemPreference]
    let occasion: String?

    init(
        items: [RecommendCatalogItem],
        recentlyWornIds: [String],
        itemPreferences: [RecommendItemPreference] = [],
        occasion: String? = nil
    ) {
        self.items = items
        self.recentlyWornIds = recentlyWornIds
        self.itemPreferences = itemPreferences
        self.occasion = occasion
    }

    func validateForWire() throws {
        guard (RecommendContractLimits.minimumItems...RecommendContractLimits.maximumItems)
            .contains(items.count) else {
            throw RecommendRequestValidationIssue.itemCount(items.count)
        }

        for item in items {
            try Self.validateRequired(
                item.id,
                field: .id,
                maximum: RecommendContractLimits.maximumItemIDLength
            )
            try Self.validateRequired(
                item.name,
                field: .name,
                maximum: RecommendContractLimits.maximumNameLength
            )
            try Self.validateRequired(
                item.category,
                field: .category,
                maximum: RecommendContractLimits.maximumCategoryLength
            )
            try Self.validateOptional(
                item.brand,
                field: .brand,
                maximum: RecommendContractLimits.maximumBrandLength
            )
            guard item.colors.count <= RecommendContractLimits.maximumColors else {
                throw RecommendRequestValidationIssue.tooManyColors
            }
            try Self.validateOptional(
                item.material,
                field: .material,
                maximum: RecommendContractLimits.maximumMaterialLength
            )
        }

        guard recentlyWornIds.count <= RecommendContractLimits.maximumRecentlyWornIDs else {
            throw RecommendRequestValidationIssue.tooManyRecentlyWornIDs
        }
        guard itemPreferences.count <= RecommendContractLimits.maximumItemPreferences else {
            throw RecommendRequestValidationIssue.tooManyItemPreferences
        }
        if let occasion,
           !RecommendContractLimits.isWithin(
               occasion,
               maximum: RecommendContractLimits.maximumOccasionLength
           ) {
            throw RecommendRequestValidationIssue.occasionTooLong
        }

        let catalogIDs = Set(items.map(\.id))
        guard recentlyWornIds.allSatisfy({ id in
            !id.isEmpty
                && RecommendContractLimits.isWithin(
                    id,
                    maximum: RecommendContractLimits.maximumItemIDLength
                )
                && catalogIDs.contains(id)
        }) else {
            throw RecommendRequestValidationIssue.invalidCatalogReference
        }
        guard itemPreferences.allSatisfy({ preference in
            !preference.id.isEmpty
                && RecommendContractLimits.isWithin(
                    preference.id,
                    maximum: RecommendContractLimits.maximumItemIDLength
                )
                && catalogIDs.contains(preference.id)
                && preference.averageRating.isFinite
                && (1.0...5.0).contains(preference.averageRating)
                && preference.ratingCount >= 1
        }) else {
            throw RecommendRequestValidationIssue.invalidItemPreference
        }
    }

    private static func validateRequired(
        _ value: String,
        field: RecommendRequestValidationIssue.CatalogField,
        maximum: Int
    ) throws {
        guard !value.isEmpty else {
            throw RecommendRequestValidationIssue.emptyCatalogField(field)
        }
        guard RecommendContractLimits.isWithin(value, maximum: maximum) else {
            throw RecommendRequestValidationIssue.catalogFieldTooLong(field)
        }
    }

    private static func validateOptional(
        _ value: String?,
        field: RecommendRequestValidationIssue.CatalogField,
        maximum: Int
    ) throws {
        guard let value else { return }
        guard RecommendContractLimits.isWithin(value, maximum: maximum) else {
            throw RecommendRequestValidationIssue.catalogFieldTooLong(field)
        }
    }
}

/// A bounded aggregate derived from on-device outfit feedback. It contains no
/// free text and only references catalog IDs already present in this request.
struct RecommendItemPreference: Codable, Sendable, Equatable {
    let id: String
    let averageRating: Double
    let ratingCount: Int
}

/// An alternative look for "show me another".
struct AlternateOutfit: Codable, Sendable, Equatable {
    let itemIds: [String]
    let rationale: String
}

struct RecommendUsage: Codable, Sendable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int

    init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case inputTokens
        case outputTokens
        case cacheCreationInputTokens
        case cacheReadInputTokens
    }

    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let untypedContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let actualKeys = Set(untypedContainer.allKeys.map(\.stringValue))
        let expectedKeys = Set(CodingKeys.allCases.map(\.rawValue))
        guard actualKeys == expectedKeys else {
            throw DecodingError.dataCorruptedError(
                forKey: .inputTokens,
                in: container,
                debugDescription: "Usage must contain exactly the shared contract fields."
            )
        }
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        cacheCreationInputTokens = try container.decode(
            Int.self,
            forKey: .cacheCreationInputTokens
        )
        cacheReadInputTokens = try container.decode(Int.self, forKey: .cacheReadInputTokens)
        guard inputTokens >= 0,
              outputTokens >= 0,
              cacheCreationInputTokens >= 0,
              cacheReadInputTokens >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .inputTokens,
                in: container,
                debugDescription: "Usage token counts must be non-negative."
            )
        }
    }
}

struct RecommendResponse: Codable, Sendable, Equatable {
    let occasion: String
    let colorStory: String
    let rationale: String
    let itemIds: [String]
    let alternates: [AlternateOutfit]
    let usage: RecommendUsage
}

enum RecommendError: Error, Equatable {
    case invalidResponse
    case http(status: Int, body: Data)
    case decoding(String)

    static func == (lhs: RecommendError, rhs: RecommendError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case let (.http(a, b), .http(c, d)): return a == c && b == d
        case let (.decoding(a), .decoding(b)): return a == b
        default: return false
        }
    }
}
