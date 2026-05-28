import Foundation

/// Test-only URLProtocol that intercepts every request issued by an attached URLSession
/// and answers it with a handler closure. Lets us drive `GmailReadOnlyClient` from
/// hand-rolled fixtures without ever touching the network.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    /// Per-test handler — set by `install(_:)`, cleared by `reset()`.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    /// Captured requests, in the order they were issued — used by tests to assert headers.
    nonisolated(unsafe) static var captured: [URLRequest] = []

    static func install(_ h: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        handler = h
        captured = []
    }

    static func reset() {
        handler = nil
        captured = []
    }

    /// Returns a URLSession whose only protocol is this stub.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.captured.append(request)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
