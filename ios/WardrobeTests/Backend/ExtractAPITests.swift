import Foundation
import Testing

@testable import Wardrobe

struct ExtractAPITests {

    @Test func requestEncodesAsSnakeCaseJSON() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let request = ExtractRequest(
            sourceMsgId: "msg-001",
            sender: "orders@everlane.com",
            subject: "Order confirmed",
            snippet: "1x Oxford Shirt $78"
        )
        let data = try encoder.encode(request)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["source_msg_id"] as? String == "msg-001")
        #expect(json["sender"] as? String == "orders@everlane.com")
        #expect(json["subject"] as? String == "Order confirmed")
        #expect(json["snippet"] as? String == "1x Oxford Shirt $78")
    }

    @Test func responseDecodesFromSnakeCaseJSON() throws {
        let body = #"""
        {
          "is_fashion": true,
          "source_msg_id": "msg-001",
          "items": [
            {
              "name": "Classic Oxford Shirt",
              "category": "top",
              "confidence": "high",
              "brand": "Everlane",
              "color": "white",
              "material": "cotton",
              "style_notes": "minimalist",
              "price": 78.0,
              "currency": "USD",
              "image_url": "https://example.com/shirt.jpg"
            }
          ],
          "usage": {
            "input_tokens": 120,
            "output_tokens": 30,
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0
          }
        }
        """#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ExtractResponse.self, from: Data(body.utf8))
        #expect(response.isFashion)
        #expect(response.sourceMsgId == "msg-001")
        #expect(response.items.count == 1)
        let item = response.items[0]
        #expect(item.category == .top)
        #expect(item.confidence == .high)
        #expect(item.styleNotes == "minimalist")
        #expect(item.price == 78.0)
        #expect(item.imageUrl == "https://example.com/shirt.jpg")
        // Dictionary keys stay snake_case — JSONDecoder's keyDecodingStrategy only
        // affects Decodable struct property names.
        #expect(response.usage["input_tokens"] == 120)
        #expect(response.usage["output_tokens"] == 30)
    }

    @Test func responseDecodesEmptyItems() throws {
        let body = #"""
        {"is_fashion": false, "source_msg_id": "x", "items": [], "usage": {"input_tokens": 10, "output_tokens": 5}}
        """#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ExtractResponse.self, from: Data(body.utf8))
        #expect(!response.isFashion)
        #expect(response.items.isEmpty)
    }
}
