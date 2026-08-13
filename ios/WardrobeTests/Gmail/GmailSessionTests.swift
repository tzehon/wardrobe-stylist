import Foundation
import Testing
import UIKit

@testable import Wardrobe

@MainActor
struct GmailSessionTests {
    private final class FakeProvider: GoogleSignInProviding {
        var hasPreviousSignIn = false
        var restoreResult: Result<GoogleSignInIdentity, Error> = .failure(
            GoogleSignInProviderFailure.noPreviousSignIn
        )
        var signInResult: Result<GoogleSignInIdentity, Error> = .failure(
            GoogleSignInProviderFailure.unavailable
        )
        var disconnectResult: Result<Void, Error> = .success(())
        private(set) var requestedScopes: [String]?
        private(set) var restoreCalls = 0
        private(set) var signOutCalls = 0
        private(set) var disconnectCalls = 0

        func restorePreviousSignIn() async throws -> GoogleSignInIdentity {
            restoreCalls += 1
            return try restoreResult.get()
        }

        func signIn(
            presenting viewController: UIViewController,
            additionalScopes: [String]
        ) async throws -> GoogleSignInIdentity {
            requestedScopes = additionalScopes
            return try signInResult.get()
        }

        func signOut() {
            signOutCalls += 1
        }

        func disconnect() async throws {
            disconnectCalls += 1
            try disconnectResult.get()
        }
    }

    private func identity(
        id: String = "stable-user-123",
        email: String = "person@example.com",
        scopes: Set<String> = Set(GmailScope.requested)
    ) -> GoogleSignInIdentity {
        GoogleSignInIdentity(stableUserID: id, email: email, grantedScopes: scopes)
    }

    private func makeSession(provider: FakeProvider) -> GmailSession {
        GmailSession(provider: provider) {
            GmailReadOnlyClient(
                transport: URLSessionGmailTransport(session: URLProtocolStub.makeSession()),
                auth: StaticTokenAuth(token: "unused")
            )
        }
    }

    @Test func restoreWithoutPreviousSignInEndsSignedOutWithoutCallingRestore() async {
        let provider = FakeProvider()
        let session = makeSession(provider: provider)

        await session.restorePreviousSignIn()

        #expect(session.status == .signedOut)
        #expect(provider.restoreCalls == 0)
        #expect(session.client == nil)
    }

    @Test func restoreValidatesGrantedReadOnlyScopeAndPublishesStableIdentity() async {
        let provider = FakeProvider()
        provider.hasPreviousSignIn = true
        provider.restoreResult = .success(identity())
        let session = makeSession(provider: provider)

        await session.restorePreviousSignIn()

        #expect(session.status == .signedIn(identity()))
        #expect(session.identity?.stableUserID == "stable-user-123")
        #expect(session.privacySubjectID == .external("stable-user-123"))
        #expect(session.client != nil)
    }

    @Test func restoredSessionMissingReadOnlyScopeRequiresReconnectAndSignsOutProvider() async {
        let provider = FakeProvider()
        provider.hasPreviousSignIn = true
        provider.restoreResult = .success(identity(scopes: ["openid", "email"]))
        let session = makeSession(provider: provider)

        await session.restorePreviousSignIn()

        guard case .reconnectRequired(let message) = session.status else {
            Issue.record("Expected reconnectRequired, got \(session.status)")
            return
        }
        #expect(message.contains("read-only"))
        #expect(provider.signOutCalls == 1)
        #expect(session.client == nil)
    }

    @Test func interactiveSignInUsesRuntimeRequestedScopeAndAcceptsGrant() async {
        let provider = FakeProvider()
        provider.signInResult = .success(identity())
        let session = makeSession(provider: provider)

        await session.signIn(presenting: UIViewController())

        #expect(provider.requestedScopes == GmailScope.requested)
        #expect(provider.requestedScopes == ["https://www.googleapis.com/auth/gmail.readonly"])
        #expect(session.status == .signedIn(identity()))
    }

    @Test func interactiveDeniedScopeRequiresReconnect() async {
        let provider = FakeProvider()
        provider.signInResult = .success(identity(scopes: []))
        let session = makeSession(provider: provider)

        await session.signIn(presenting: UIViewController())

        #expect(provider.requestedScopes == GmailScope.requested)
        #expect(provider.signOutCalls == 1)
        if case .reconnectRequired = session.status {
            // Expected.
        } else {
            Issue.record("Expected reconnectRequired, got \(session.status)")
        }
    }

    @Test func cancelledSignInIsFriendlyAndLeavesNoClient() async {
        let provider = FakeProvider()
        provider.signInResult = .failure(GoogleSignInProviderFailure.cancelled)
        let session = makeSession(provider: provider)

        await session.signIn(presenting: UIViewController())

        #expect(session.status == .cancelled)
        #expect(session.state == .signedOut)
        #expect(session.client == nil)
    }

    @Test func expiredRestoreRequiresReconnect() async {
        let provider = FakeProvider()
        provider.hasPreviousSignIn = true
        provider.restoreResult = .failure(GoogleSignInProviderFailure.reconnectRequired)
        let session = makeSession(provider: provider)

        await session.restorePreviousSignIn()

        if case .reconnectRequired(let message) = session.status {
            #expect(message.contains("renewed"))
        } else {
            Issue.record("Expected reconnectRequired, got \(session.status)")
        }
    }

    @Test func providerFailureUsesFriendlyMessageWithoutRawErrorDetails() async {
        let provider = FakeProvider()
        provider.signInResult = .failure(GoogleSignInProviderFailure.unavailable)
        let session = makeSession(provider: provider)

        await session.signIn(presenting: UIViewController())

        #expect(session.status == .failed(message: "We couldn’t connect to Google. Please try again."))
    }

    @Test func disconnectRevokesThroughProviderAndClearsSession() async {
        let provider = FakeProvider()
        provider.signInResult = .success(identity())
        let session = makeSession(provider: provider)
        await session.signIn(presenting: UIViewController())

        await session.disconnect()

        #expect(provider.disconnectCalls == 1)
        #expect(session.status == .signedOut)
        #expect(session.client == nil)
    }

    @Test func disconnectFailureIsFriendlyAndStillDropsClient() async {
        let provider = FakeProvider()
        provider.signInResult = .success(identity())
        provider.disconnectResult = .failure(GoogleSignInProviderFailure.unavailable)
        let session = makeSession(provider: provider)
        await session.signIn(presenting: UIViewController())

        await session.disconnect()

        #expect(session.status == .failed(message: "We couldn’t disconnect Google. Please try again."))
        #expect(session.client == nil)
    }
}
