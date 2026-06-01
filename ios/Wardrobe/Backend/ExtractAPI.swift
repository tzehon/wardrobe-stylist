import Foundation

/// Wire types for `POST /extract` on the Wardrobe backend. Property names are
/// Swift-camelCase; JSONEncoder/JSONDecoder is configured with snake_case
/// strategies so the wire format matches the backend's Pydantic models
/// (`shared/schemas/purchase.schema.json` is the contract).

enum FashionCategory: String, Codable, Sendable, Equatable {
    case top, bottom, dress, outerwear, shoe, bag, jewelry, accessory
}

enum FashionConfidence: String, Codable, Sendable, Equatable {
    case high, medium, low
}

struct ExtractRequest: Codable, Sendable, Equatable {
    let sourceMsgId: String
    let sender: String?
    let subject: String?
    let snippet: String

    init(sourceMsgId: String, sender: String?, subject: String?, snippet: String) {
        self.sourceMsgId = sourceMsgId
        self.sender = sender
        self.subject = subject
        self.snippet = snippet
    }
}

struct ExtractedItem: Codable, Sendable, Equatable {
    let name: String
    let category: FashionCategory
    let confidence: FashionConfidence
    let brand: String?
    let color: String?
    let material: String?
    let styleNotes: String?
    let price: Double?
    let currency: String?
    let imageUrl: String?
}

struct ExtractResponse: Codable, Sendable, Equatable {
    let isFashion: Bool
    let sourceMsgId: String
    let items: [ExtractedItem]
    /// Token counts the backend echoed (`input_tokens`, `output_tokens`,
    /// `cache_creation_input_tokens`, `cache_read_input_tokens`). Dictionary keys
    /// stay snake_case — `JSONDecoder.keyDecodingStrategy` only rewrites struct
    /// property names, not `[String: Value]` keys.
    let usage: [String: Int]
}

enum ExtractError: Error, Equatable {
    case invalidResponse
    case http(status: Int, body: Data)
    case decoding(String)

    static func == (lhs: ExtractError, rhs: ExtractError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case let (.http(a, b), .http(c, d)): return a == c && b == d
        case let (.decoding(a), .decoding(b)): return a == b
        default: return false
        }
    }
}
