import Foundation
import Observation
import UIKit

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

    /// Detailed lifecycle used by hardened flows. `state` remains as a legacy
    /// projection until the app shell adopts these richer states directly.
    enum Status: Equatable {
        case restoring
        case signedOut
        case signingIn
        case signedIn(GoogleSignInIdentity)
        case reconnectRequired(message: String)
        case cancelled
        case failed(message: String)
    }

    private(set) var state: State = .signedOut
    private(set) var status: Status = .signedOut {
        didSet { state = Self.legacyState(for: status) }
    }
    private(set) var client: GmailReadOnlyClient?

    var identity: GoogleSignInIdentity? {
        guard case .signedIn(let identity) = status else { return nil }
        return identity
    }

    var privacySubjectID: PrivacySubjectID? {
        identity?.privacySubjectID
    }

    private let provider: any GoogleSignInProviding
    private let makeClient: @MainActor @Sendable () -> GmailReadOnlyClient

    init(
        provider: any GoogleSignInProviding = SystemGoogleSignInProvider(),
        makeClient: @escaping @MainActor @Sendable () -> GmailReadOnlyClient = {
            GmailReadOnlyClient(
                transport: URLSessionGmailTransport(),
                auth: GoogleSignInGmailAuth()
            )
        }
    ) {
        self.provider = provider
        self.makeClient = makeClient
    }

    /// Tries to restore a prior session at launch — quick, silent, no UI.
    func restorePreviousSignIn() async {
        status = .restoring
        guard provider.hasPreviousSignIn else {
            status = .signedOut
            return
        }
        do {
            let identity = try await provider.restorePreviousSignIn()
            activate(identity)
        } catch {
            handle(error, duringRestore: true)
        }
    }

    /// Interactive sign-in. Requests *only* the read-only Gmail scope; verifies it was
    /// actually granted before activating the client.
    func signIn(presenting: UIViewController) async {
        status = .signingIn
        do {
            let identity = try await provider.signIn(
                presenting: presenting,
                additionalScopes: GmailScope.requested
            )
            activate(identity)
        } catch {
            handle(error, duringRestore: false)
        }
    }

    func signOut() {
        provider.signOut()
        client = nil
        status = .signedOut
    }

    /// Revokes the app's OAuth grants through GoogleSignIn, then clears the local
    /// session. This is intentionally distinct from a local-only sign out.
    func disconnect() async {
        client = nil
        do {
            try await provider.disconnect()
            status = .signedOut
        } catch {
            status = .failed(message: "We couldn’t disconnect Google. Please try again.")
        }
    }

    private func activate(_ identity: GoogleSignInIdentity) {
        guard Set(GmailScope.requested).isSubset(of: identity.grantedScopes) else {
            provider.signOut()
            client = nil
            status = .reconnectRequired(
                message: "Gmail read-only access is required to import receipts. Reconnect and allow read-only access."
            )
            return
        }
        client = makeClient()
        status = .signedIn(identity)
    }

    private func handle(_ error: Error, duringRestore: Bool) {
        client = nil
        switch error as? GoogleSignInProviderFailure {
        case .cancelled:
            status = .cancelled
        case .noPreviousSignIn:
            status = .signedOut
        case .reconnectRequired:
            status = .reconnectRequired(
                message: "Your Google connection needs to be renewed. Sign in again to continue."
            )
        case .invalidIdentity, .unavailable, .none:
            status = .failed(message: duringRestore
                ? "We couldn’t restore your Google connection. Please sign in again."
                : "We couldn’t connect to Google. Please try again.")
        }
    }

    private static func legacyState(for status: Status) -> State {
        switch status {
        case .restoring, .signingIn:
            .signingIn
        case .signedOut, .cancelled:
            .signedOut
        case .signedIn(let identity):
            .signedIn(email: identity.email)
        case .reconnectRequired(let message), .failed(let message):
            .failed(message: message)
        }
    }
}
