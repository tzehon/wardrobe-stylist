import Foundation

/// Wire types for `POST /recommend` on the Wardrobe backend (Phase 5, "Aria").
/// Property names are Swift-camelCase; JSONEncoder/JSONDecoder is configured with
/// snake_case strategies so the wire format matches the backend's Pydantic models
/// (`shared/schemas/outfit.schema.json` is the contract for the response).

/// One catalog item, compacted to the minimum Aria needs to style — no images,
/// no purchase metadata. Ids are the SwiftData `Item.id` (UUID) as a string.
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
    let occasion: String?

    init(items: [RecommendCatalogItem], recentlyWornIds: [String], occasion: String? = nil) {
        self.items = items
        self.recentlyWornIds = recentlyWornIds
        self.occasion = occasion
    }
}

/// An alternative look for "show me another".
struct AlternateOutfit: Codable, Sendable, Equatable {
    let itemIds: [String]
    let rationale: String
}

struct RecommendResponse: Codable, Sendable, Equatable {
    let occasion: String
    let colorStory: String
    let rationale: String
    let itemIds: [String]
    let alternates: [AlternateOutfit]
    /// Token counts the backend echoed. Dictionary keys stay snake_case —
    /// `JSONDecoder.keyDecodingStrategy` only rewrites struct property names.
    let usage: [String: Int]
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
