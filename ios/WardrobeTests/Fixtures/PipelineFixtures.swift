import Foundation

@testable import Wardrobe

/// Helpers that build Gmail + backend response payloads at runtime — keeps
/// pipeline tests self-contained without needing to hand-encode base64url body
/// blobs.
enum PipelineFixtures {

    /// Minimal Gmail `messages.list` response (no `nextPageToken` → the
    /// `allMessages` async stream terminates after one HTTP round trip).
    static func messageListJSON(ids: [String]) throws -> Data {
        let messages = ids.map { id in
            ["id": id, "threadId": "t-\(id)"]
        }
        return try JSONSerialization.data(withJSONObject: [
            "messages": messages,
            "resultSizeEstimate": ids.count,
        ])
    }

    /// Minimal Gmail `messages.get` response with text/plain body + From/Subject.
    static func messageJSON(
        id: String,
        sender: String,
        subject: String,
        body: String,
        labels: [String] = ["INBOX"]
    ) throws -> Data {
        let bodyB64 = Base64URL.encode(Data(body.utf8))
        let payload: [String: Any] = [
            "id": id,
            "threadId": "t-\(id)",
            "labelIds": labels,
            "internalDate": "1716745200000",  // 2024-05-26 17:00 UTC — stable value
            "payload": [
                "mimeType": "text/plain",
                "headers": [
                    ["name": "From", "value": sender],
                    ["name": "Subject", "value": subject],
                ],
                "body": ["data": bodyB64],
            ] as [String: Any],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Minimal backend `/extract` happy-path response.
    static func extractFashionResponseJSON(
        sourceMsgId: String,
        itemName: String,
        brand: String,
        price: Double,
        currency: String = "USD",
        imageURL: String? = nil
    ) throws -> Data {
        var item: [String: Any] = [
            "name": itemName,
            "category": "top",
            "confidence": "high",
            "brand": brand,
            "color": "white",
            "price": price,
            "currency": currency,
        ]
        if let imageURL { item["image_url"] = imageURL }
        return try JSONSerialization.data(withJSONObject: [
            "is_fashion": true,
            "source_msg_id": sourceMsgId,
            "items": [item],
            "usage": ["input_tokens": 100, "output_tokens": 50],
        ])
    }

    /// Backend `/extract` not-a-fashion-purchase response.
    static func extractNotFashionResponseJSON(sourceMsgId: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "is_fashion": false,
            "source_msg_id": sourceMsgId,
            "items": [],
            "usage": ["input_tokens": 80, "output_tokens": 20],
        ])
    }
}
