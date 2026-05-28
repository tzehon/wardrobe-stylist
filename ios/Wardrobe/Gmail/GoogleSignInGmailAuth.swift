import Foundation
@preconcurrency import GoogleSignIn

/// `GmailAuth` backed by the GoogleSignIn-iOS SDK. Asks the SDK for the current user's
/// access token, transparently refreshing if it's near expiry. Runs on the main actor
/// because the SDK touches UIKit state internally.
///
/// `@preconcurrency` quiets Sendable warnings from the SDK's pre-Swift-6 API surface — our
/// own usage stays on a single actor, so this is safe.
@MainActor
struct GoogleSignInGmailAuth: GmailAuth {
    func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GmailError.notAuthenticated
        }
        let refreshed = try await user.refreshTokensIfNeeded()
        return refreshed.accessToken.tokenString
    }
}
