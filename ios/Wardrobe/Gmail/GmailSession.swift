import Foundation
import Observation
import UIKit
@preconcurrency import GoogleSignIn

/// Holds the Gmail sign-in state and exposes a configured `GmailReadOnlyClient` when
/// signed in. SwiftUI observes `state` and re-renders. All sign-in/out work happens on
/// the main actor because the SDK presents UI.
@MainActor
@Observable
final class GmailSession {

    enum State: Equatable {
        case signedOut
        case signingIn
        case signedIn(email: String)
        case failed(message: String)
    }

    var state: State = .signedOut
    private(set) var client: GmailReadOnlyClient?

    /// Tries to restore a prior session at launch — quick, silent, no UI.
    func restorePreviousSignIn() async {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        do {
            _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try await activateAndFetchProfile()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Interactive sign-in. Requests *only* the read-only Gmail scope; verifies it was
    /// actually granted before activating the client.
    func signIn(presenting: UIViewController) async {
        state = .signingIn
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: [GmailScope.readonly]
            )
            let granted = result.user.grantedScopes ?? []
            guard granted.contains(GmailScope.readonly) else {
                let got = granted.isEmpty ? "(nothing)" : granted.joined(separator: ", ")
                state = .failed(message: """
                    Gmail read-only access was not granted.
                    Expected: \(GmailScope.readonly)
                    Got:      \(got)
                    Fix: add the gmail.readonly scope to your GCP Data access page, then \
                    revoke the app at myaccount.google.com/permissions and sign in again.
                    """)
                return
            }
            try await activateAndFetchProfile()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        client = nil
        state = .signedOut
    }

    /// Builds the read-only client and uses it to fetch the profile as a smoke check.
    /// Surfaces the email address back into `state`.
    private func activateAndFetchProfile() async throws {
        let c = GmailReadOnlyClient(
            transport: URLSessionGmailTransport(),
            auth: GoogleSignInGmailAuth()
        )
        self.client = c
        let profile = try await c.getProfile()
        self.state = .signedIn(email: profile.emailAddress)
    }
}
