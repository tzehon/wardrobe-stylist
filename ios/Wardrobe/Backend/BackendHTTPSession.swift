import Foundation

/// A backend-only transport that keeps authentication and private request data
/// out of the app-wide cookie, credential, and URL caches. Backend API paths are
/// fixed; a redirect is therefore a configuration or security failure, never a
/// navigation instruction the client should follow with an assertion, bearer,
/// receipt snippet, or wardrobe catalog attached.
enum BackendHTTPSession {
    static let shared = make()

    static func make(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(
            configuration: configuration,
            delegate: BackendRedirectBlocker(),
            delegateQueue: nil
        )
    }
}

enum BackendRedirectPolicy {
    static func redirectedRequest(
        for response: HTTPURLResponse,
        proposedRequest: URLRequest
    ) -> URLRequest? {
        _ = response
        _ = proposedRequest
        return nil
    }
}

final class BackendRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(BackendRedirectPolicy.redirectedRequest(
            for: response,
            proposedRequest: request
        ))
    }
}
