import Foundation

/// Things the Gmail client can fail with. Distinct cases let tests and callers react
/// precisely (e.g. retry on transient HTTP errors, surface decoding bugs).
enum GmailError: Error, Equatable {
    case invalidResponse
    case http(status: Int, body: Data)
    case decoding(String)
    case notAuthenticated

    static func == (lhs: GmailError, rhs: GmailError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case (.notAuthenticated, .notAuthenticated): return true
        case let (.http(a, b), .http(c, d)): return a == c && b == d
        case let (.decoding(a), .decoding(b)): return a == b
        default: return false
        }
    }
}

/// The only thing that ever talks to Gmail.
///
/// Composed of two seams: a transport (HTTP) and an auth provider (token). Every call
/// resolves a `GmailReadEndpoint` (an allowlist enum — see `GmailReadEndpoint.swift`) into
/// a `URLRequest` with method `GET`, sets a Bearer token, and decodes JSON. There is no
/// code path here that can issue a non-GET request, which — together with
/// `GmailReadOnlyGuardTests` — is what makes this app *structurally* read-only.
struct GmailReadOnlyClient: Sendable {
    let transport: GmailTransport
    let auth: GmailAuth
    let decoder: JSONDecoder

    init(transport: GmailTransport, auth: GmailAuth, decoder: JSONDecoder = .init()) {
        self.transport = transport
        self.auth = auth
        self.decoder = decoder
    }

    // MARK: - Typed endpoints

    func getProfile() async throws -> GmailProfile {
        try await send(.getProfile)
    }

    func listMessages(
        query: String,
        includeSpamTrash: Bool = true,
        pageToken: String? = nil
    ) async throws -> GmailMessageList {
        try await send(.listMessages(
            query: query, includeSpamTrash: includeSpamTrash, pageToken: pageToken
        ))
    }

    func getMessage(id: String) async throws -> GmailMessage {
        try await send(.getMessage(id: id))
    }

    func getAttachment(messageId: String, attachmentId: String) async throws -> GmailAttachment {
        try await send(.getAttachment(messageId: messageId, attachmentId: attachmentId))
    }

    func listHistory(
        startHistoryId: String,
        pageToken: String? = nil
    ) async throws -> GmailHistory {
        try await send(.listHistory(startHistoryId: startHistoryId, pageToken: pageToken))
    }

    /// Streams every matching message ref across all pages of `listMessages`.
    func allMessages(
        query: String,
        includeSpamTrash: Bool = true
    ) -> AsyncThrowingStream<GmailMessageList.MessageRef, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var pageToken: String? = nil
                do {
                    repeat {
                        let page = try await listMessages(
                            query: query,
                            includeSpamTrash: includeSpamTrash,
                            pageToken: pageToken
                        )
                        for ref in page.messages ?? [] {
                            continuation.yield(ref)
                        }
                        pageToken = page.nextPageToken
                    } while pageToken != nil
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Single dispatch point (the only place HTTP happens)

    private func send<T: Decodable & Sendable>(
        _ endpoint: GmailReadEndpoint,
        decode _: T.Type = T.self
    ) async throws -> T {
        let token = try await auth.accessToken()
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.httpMethod         // always "GET" — see GmailReadEndpoint
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport.perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw GmailError.http(status: response.statusCode, body: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GmailError.decoding(String(describing: error))
        }
    }
}
