import Foundation
import Testing

@testable import Wardrobe

struct ExtractClientTests {

    private let baseURL = URL(string: "http://test.local")!

    private func makeClient(token: String = "test-token") -> ExtractClient {
        ExtractClient(
            baseURL: baseURL,
            deviceToken: token,
            session: URLProtocolStub.makeSession()
        )
    }

    private func makeHTTPResponse(
        _ status: Int,
        url: URL? = nil
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? URL(string: "http://test.local/extract")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private let successBody: String = #"""
    {
      "is_fashion": true,
      "source_msg_id": "msg-001",
      "items": [
        {
          "name": "Classic Oxford Shirt",
          "category": "top",
          "confidence": "high",
          "brand": "Everlane",
          "price": 78.0,
          "currency": "USD"
        }
      ],
      "usage": {"input_tokens": 120, "output_tokens": 30}
    }
    """#

    // MARK: -

    @Test func sendsBearerTokenAndJSONBodyToExtractPath() async throws {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient(token: "abc-123")
        let response = try await client.extract(ExtractRequest(
            sourceMsgId: "msg-001",
            sender: "orders@everlane.com",
            subject: "Order confirmed",
            snippet: "1x Oxford Shirt $78"
        ))

        #expect(response.isFashion)
        #expect(response.items.first?.name == "Classic Oxford Shirt")

        let req = try #require(URLProtocolStub.captured.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/extract")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // Body went through `convertToSnakeCase`.
        let body = try #require(URLProtocolStub.capturedBodies.first)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["source_msg_id"] as? String == "msg-001")
        #expect(json["snippet"] as? String == "1x Oxford Shirt $78")
    }

    @Test func http401IsSurfacedAsHttpError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(401), Data(#"{"detail": "Invalid bearer token."}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.extract(ExtractRequest(
                sourceMsgId: "m", sender: nil, subject: nil, snippet: "x"
            ))
            Issue.record("Expected ExtractError.http")
        } catch let ExtractError.http(status, _) {
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
        await #expect(throws: ExtractError.self) {
            _ = try await client.extract(ExtractRequest(
                sourceMsgId: "m", sender: nil, subject: nil, snippet: "x"
            ))
        }
    }

    @Test func malformedBodyIsSurfacedAsDecodingError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data("not json".utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.extract(ExtractRequest(
                sourceMsgId: "m", sender: nil, subject: nil, snippet: "x"
            ))
            Issue.record("Expected decoding error")
        } catch let ExtractError.decoding(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func notFashionResponseDecodesWithEmptyItems() async throws {
        let body = #"""
        {"is_fashion": false, "source_msg_id": "m2", "items": [], "usage": {"input_tokens": 10, "output_tokens": 5}}
        """#
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(body.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        let response = try await client.extract(ExtractRequest(
            sourceMsgId: "m2", sender: nil, subject: nil, snippet: "USB cable"
        ))
        #expect(!response.isFashion)
        #expect(response.items.isEmpty)
    }
}
