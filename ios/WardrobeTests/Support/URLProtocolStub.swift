import Foundation

/// Test-only URLProtocol that intercepts every request issued by an attached URLSession
/// and answers it with a handler closure. Lets us drive `GmailReadOnlyClient` from
/// hand-rolled fixtures without ever touching the network.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    /// Per-test handler — set by `install(_:)`, cleared by `reset()`.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    /// Captured requests, in the order they were issued — used by tests to assert headers.
    nonisolated(unsafe) static var captured: [URLRequest] = []

    /// Captured request bodies, parallel to `captured`. URLSession often promotes
    /// `httpBody` to `httpBodyStream` before the request reaches URLProtocol, so we
    /// read the stream here once and stash the bytes for tests to assert on.
    nonisolated(unsafe) static var capturedBodies: [Data] = []

    static func install(_ h: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        handler = h
        captured = []
        capturedBodies = []
    }

    static func reset() {
        handler = nil
        captured = []
        capturedBodies = []
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
        Self.capturedBodies.append(Self.readBody(of: request))
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

    /// Reads the request body from `httpBody` if set, otherwise drains `httpBodyStream`.
    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
