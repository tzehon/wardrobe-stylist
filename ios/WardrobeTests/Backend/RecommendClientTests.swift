import Foundation
import Testing

@testable import Wardrobe

struct RecommendClientTests {

    private let baseURL = URL(string: "http://test.local")!

    private func makeClient(token: String = "test-token") -> RecommendClient {
        RecommendClient(
            baseURL: baseURL,
            deviceToken: token,
            session: URLProtocolStub.makeSession()
        )
    }

    private func makeHTTPResponse(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "http://test.local/recommend")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private let successBody: String = #"""
    {
      "occasion": "relaxed weekend",
      "color_story": "soft neutrals with a tan warmth",
      "rationale": "The tee keeps the trouser easy; suede warms it up.",
      "item_ids": ["a", "b", "c"],
      "alternates": [
        {"item_ids": ["a", "b", "d"], "rationale": "Layer the jacket when it cools."}
      ],
      "usage": {"input_tokens": 200, "output_tokens": 60}
    }
    """#

    private func sampleRequest() -> RecommendRequest {
        RecommendRequest(
            items: [
                RecommendCatalogItem(id: "a", name: "Oversized Tee", category: "top", colors: ["white"]),
                RecommendCatalogItem(id: "b", name: "Slim Trouser", category: "bottom", colors: ["navy"]),
                RecommendCatalogItem(id: "c", name: "Suede Loafers", category: "shoe"),
            ],
            recentlyWornIds: ["d"],
            occasion: "relaxed weekend"
        )
    }

    // MARK: -

    @Test func sendsBearerTokenAndSnakeCaseBodyToRecommendPath() async throws {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient(token: "abc-123")
        let response = try await client.recommend(sampleRequest())

        #expect(response.itemIds == ["a", "b", "c"])
        #expect(response.occasion == "relaxed weekend")
        #expect(response.colorStory == "soft neutrals with a tan warmth")
        #expect(response.alternates.first?.itemIds == ["a", "b", "d"])
        #expect(response.usage["input_tokens"] == 200)

        let req = try #require(URLProtocolStub.captured.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/recommend")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // Body went through `convertToSnakeCase`.
        let body = try #require(URLProtocolStub.capturedBodies.first)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["recently_worn_ids"] as? [String] == ["d"])
        #expect(json["occasion"] as? String == "relaxed weekend")
        let items = try #require(json["items"] as? [[String: Any]])
        #expect(items.first?["id"] as? String == "a")
    }

    @Test func http401IsSurfacedAsHttpError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(401), Data(#"{"detail": "Invalid bearer token."}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.recommend(sampleRequest())
            Issue.record("Expected RecommendError.http")
        } catch let RecommendError.http(status, _) {
            #expect(status == 401)
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func http502IsSurfacedAsHttpError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(502), Data(#"{"detail": "Model returned bad input."}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        await #expect(throws: RecommendError.self) {
            _ = try await client.recommend(self.sampleRequest())
        }
    }

    @Test func malformedBodyIsSurfacedAsDecodingError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data("not json".utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.recommend(sampleRequest())
            Issue.record("Expected decoding error")
        } catch let RecommendError.decoding(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func emptyAlternatesDecode() async throws {
        let body = #"""
        {"occasion": "smart office", "color_story": "monochrome", "rationale": "Clean column.",
         "item_ids": ["a", "b"], "alternates": [], "usage": {"input_tokens": 10, "output_tokens": 5}}
        """#
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(body.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        let response = try await client.recommend(sampleRequest())
        #expect(response.alternates.isEmpty)
        #expect(response.itemIds == ["a", "b"])
    }
}
