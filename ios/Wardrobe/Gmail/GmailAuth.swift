import Foundation

/// Produces a valid OAuth2 access token, refreshing if necessary.
///
/// `GmailReadOnlyClient` requests a token from this provider for every call, so callers can
/// implement caching/refresh internally without the client knowing about it. The
/// GoogleSignIn-backed implementation lives in `GoogleSignInGmailAuth` (Phase 1b).
protocol GmailAuth: Sendable {
    func accessToken() async throws -> String
}

/// Trivial implementation that always returns the same token — used by tests and for
/// short-lived dev experiments. Not for production use.
struct StaticTokenAuth: GmailAuth {
    let token: String
    func accessToken() async throws -> String { token }
}
