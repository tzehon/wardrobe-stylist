import Foundation

/// Supplies a short-lived bearer for one backend request. Implementations must
/// never expose a long-lived shared client secret. When the backend rejects a
/// token, the caller passes it back so a concurrent refresh isn't repeated.
protocol BackendAuthorizing: Sendable {
    func accessToken(rejecting rejectedToken: String?) async throws -> String
}

/// Deterministic seam for URLProtocol-based client tests. Production wiring
/// always uses `AppAttestAuthorization.shared`.
struct StaticBackendAuthorization: BackendAuthorizing {
    let token: String

    init(token: String) {
        self.token = token
    }

    func accessToken(rejecting rejectedToken: String?) async throws -> String {
        token
    }
}
