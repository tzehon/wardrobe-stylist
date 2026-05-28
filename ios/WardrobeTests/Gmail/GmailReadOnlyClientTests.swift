import Foundation
import Testing

@testable import Wardrobe

/// Drives `GmailReadOnlyClient` against the URLProtocolStub. Every test starts from a
/// fresh stub state so they're order-independent.
struct GmailReadOnlyClientTests {

    private func makeClient(token: String = "test-token") -> GmailReadOnlyClient {
        let transport = URLSessionGmailTransport(session: URLProtocolStub.makeSession())
        return GmailReadOnlyClient(transport: transport, auth: StaticTokenAuth(token: token))
    }

    private func httpResponse(
        _ status: Int,
        url: URL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    // MARK: -

    @Test func getProfileDecodesAndSendsBearerToken() async throws {
        URLProtocolStub.install { _ in
            (self.httpResponse(200), Data(GmailFixtures.profileJSON.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient(token: "abc123")
        let profile = try await client.getProfile()

        #expect(profile.emailAddress == "user@example.com")
        let req = try #require(URLProtocolStub.captured.first)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path == "/gmail/v1/users/me/profile")
    }

    @Test func listMessagesSendsExpectedQueryParameters() async throws {
        URLProtocolStub.install { _ in
            (self.httpResponse(200), Data(GmailFixtures.messageListPage1JSON.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        _ = try await client.listMessages(query: "subject:receipt", includeSpamTrash: true)

        let req = try #require(URLProtocolStub.captured.first)
        let qs = req.url?.query ?? ""
        #expect(qs.contains("q=subject:receipt") || qs.contains("q=subject%3Areceipt"))
        #expect(qs.contains("includeSpamTrash=true"))
    }

    @Test func allMessagesIteratesPagesUntilEmpty() async throws {
        // First call returns page 1 with nextPageToken; second call returns page 2 with no token.
        let calls = Counter()
        URLProtocolStub.install { _ in
            let body = calls.bump() == 0
                ? GmailFixtures.messageListPage1JSON
                : GmailFixtures.messageListPage2JSON
            return (self.httpResponse(200), Data(body.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        var ids: [String] = []
        for try await ref in client.allMessages(query: "x") {
            ids.append(ref.id)
        }
        #expect(ids == ["m1", "m2", "m3"])
        #expect(URLProtocolStub.captured.count == 2)
        // The second call must carry the page token from the first response.
        let secondQuery = URLProtocolStub.captured[1].url?.query ?? ""
        #expect(secondQuery.contains("pageToken=PT_2"))
    }

    @Test func http401IsSurfacedAsHttpError() async throws {
        URLProtocolStub.install { _ in
            (self.httpResponse(401), Data("{\"error\":\"unauthorized\"}".utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        await #expect(throws: GmailError.self) {
            _ = try await client.getProfile()
        }
    }

    @Test func malformedBodyIsSurfacedAsDecodingError() async throws {
        URLProtocolStub.install { _ in
            (self.httpResponse(200), Data("not json".utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.getProfile()
            Issue.record("Expected decoding error")
        } catch let GmailError.decoding(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

/// Tiny call counter that's safe to share across the stub closure boundary.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func bump() -> Int { lock.lock(); defer { lock.unlock() }; defer { value += 1 }; return value }
}
