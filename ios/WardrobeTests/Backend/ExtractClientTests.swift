import Foundation
import Testing

@testable import Wardrobe

struct ExtractClientTests {

    private let baseURL = URL(string: "http://test.local")!

    private func makeClient(token: String = "test-token") -> ExtractClient {
        ExtractClient(
            baseURL: baseURL,
            authorization: StaticBackendAuthorization(token: token),
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
        #expect(req.timeoutInterval == 30)
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

    @Test func http401RefreshesAuthorizationAndRetriesExactlyOnce() async throws {
        let authorization = ExtractRotatingAuthorization(
            initialToken: "expired-token",
            refreshedToken: "refreshed-token"
        )
        URLProtocolStub.install { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-token" {
                return (
                    self.makeHTTPResponse(401),
                    Data(#"{"detail": "Expired bearer token."}"#.utf8)
                )
            }
            return (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = ExtractClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        let response = try await client.extract(ExtractRequest(
            sourceMsgId: "msg-001",
            sender: nil,
            subject: nil,
            snippet: "Oxford Shirt"
        ))

        #expect(response.items.first?.name == "Classic Oxford Shirt")
        #expect(URLProtocolStub.captured.map {
            $0.value(forHTTPHeaderField: "Authorization")
        } == ["Bearer expired-token", "Bearer refreshed-token"])
        let rejectedTokens = await authorization.rejectedTokens
        #expect(rejectedTokens.count == 2)
        #expect(rejectedTokens[0] == nil)
        #expect(rejectedTokens[1] == "expired-token")
    }

    @Test func late401ForADeletedIdentityDoesNotResendTheReceiptPayload() async {
        let authorization = ExtractRetiredBearerAuthorization(
            retiredToken: "deleted-identity-token"
        )
        URLProtocolStub.install { _ in
            (
                self.makeHTTPResponse(401),
                Data(#"{"detail": "Deleted anonymous identity."}"#.utf8)
            )
        }
        defer { URLProtocolStub.reset() }

        let client = ExtractClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await client.extract(ExtractRequest(
                sourceMsgId: "private-message",
                sender: "orders@example.com",
                subject: "Private receipt",
                snippet: "Private receipt contents"
            ))
        }

        #expect(URLProtocolStub.captured.count == 1)
        #expect(URLProtocolStub.capturedBodies.count == 1)
        #expect(
            URLProtocolStub.capturedBodies[0]
                .range(of: Data("Private receipt contents".utf8)) != nil
        )
        #expect(await authorization.replacementTokenCount == 0)
        #expect(await authorization.rejectedTokens == [nil, "deleted-identity-token"])
    }

    @Test func cancellationWhileAuthorizationIsSuspendedSendsNoReceiptPayload() async {
        let authorization = ExtractSuspendedAuthorization()
        URLProtocolStub.install { _ in
            Issue.record("A canceled extraction must not send its receipt payload")
            return (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = ExtractClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        let task = Task {
            try await client.extract(ExtractRequest(
                sourceMsgId: "private-message",
                sender: "orders@example.com",
                subject: "Private receipt",
                snippet: "Private receipt contents"
            ))
        }

        await authorization.waitUntilRequested()
        task.cancel()
        await authorization.resume(with: "unused-token")

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(URLProtocolStub.capturedBodies.isEmpty)
    }

    @Test func crossOrigin307DoesNotForwardBearerOrReceiptPayload() throws {
        let response = makeHTTPResponse(307)
        var proposed = URLRequest(url: URL(string: "https://attacker.example/collect")!)
        proposed.httpMethod = "POST"
        proposed.setValue(
            "Bearer short-lived-private-token",
            forHTTPHeaderField: "Authorization"
        )
        proposed.httpBody = try JSONEncoder().encode(ExtractRequest(
            sourceMsgId: "private-message",
            sender: "orders@example.com",
            subject: "Private receipt",
            snippet: "Private receipt contents"
        ))

        #expect(BackendRedirectPolicy.redirectedRequest(
            for: response,
            proposedRequest: proposed
        ) == nil)
        #expect(proposed.value(forHTTPHeaderField: "Authorization") != nil)
        #expect(proposed.httpBody?.range(of: Data("Private receipt contents".utf8)) != nil)
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

private actor ExtractRotatingAuthorization: BackendAuthorizing {
    private let initialToken: String
    private let refreshedToken: String
    private(set) var rejectedTokens: [String?] = []

    init(initialToken: String, refreshedToken: String) {
        self.initialToken = initialToken
        self.refreshedToken = refreshedToken
    }

    func accessToken(rejecting rejectedToken: String?) -> String {
        rejectedTokens.append(rejectedToken)
        return rejectedToken == nil ? initialToken : refreshedToken
    }
}

private actor ExtractSuspendedAuthorization: BackendAuthorizing {
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var tokenContinuation: CheckedContinuation<String, Error>?

    func accessToken(rejecting rejectedToken: String?) async throws -> String {
        didStart = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters.removeAll()
        return try await withCheckedThrowingContinuation { continuation in
            tokenContinuation = continuation
        }
    }

    func waitUntilRequested() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func resume(with token: String) {
        tokenContinuation?.resume(returning: token)
        tokenContinuation = nil
    }
}

private actor ExtractRetiredBearerAuthorization: BackendAuthorizing {
    private let retiredToken: String
    private(set) var rejectedTokens: [String?] = []
    private(set) var replacementTokenCount = 0

    init(retiredToken: String) {
        self.retiredToken = retiredToken
    }

    func accessToken(rejecting rejectedToken: String?) throws -> String {
        rejectedTokens.append(rejectedToken)
        guard let rejectedToken else { return retiredToken }
        guard rejectedToken != retiredToken else {
            throw AppAttestAuthorizationError.retiredSession
        }
        replacementTokenCount += 1
        return "unexpected-replacement-token"
    }
}
