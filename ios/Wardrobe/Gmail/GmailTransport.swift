import Foundation

/// Abstraction over the HTTP transport so tests can swap a stubbed URLSession in without
/// touching `GmailReadOnlyClient` — and so the client has a single, auditable seam.
protocol GmailTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Production transport: a thin wrapper around URLSession.
struct URLSessionGmailTransport: GmailTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }
        return (data, http)
    }
}
