import Foundation
import UIKit
@preconcurrency import GoogleSignIn

/// Provider-neutral value copied out of GoogleSignIn's non-Sendable SDK model.
/// `stableUserID` is Google's stable user identifier, not an email address.
struct GoogleSignInIdentity: Equatable, Sendable {
    let stableUserID: String
    let email: String
    let grantedScopes: Set<String>

    var privacySubjectID: PrivacySubjectID {
        .external(stableUserID)
    }
}

enum GoogleSignInProviderFailure: Error, Equatable, Sendable {
    case cancelled
    case noPreviousSignIn
    case reconnectRequired
    case invalidIdentity
    case unavailable
}

/// Main-actor seam around GoogleSignIn so session behavior can be tested without
/// presenting SDK UI or constructing `GIDGoogleUser` instances.
@MainActor
protocol GoogleSignInProviding: AnyObject {
    var hasPreviousSignIn: Bool { get }

    func restorePreviousSignIn() async throws -> GoogleSignInIdentity
    func signIn(
        presenting viewController: UIViewController,
        additionalScopes: [String]
    ) async throws -> GoogleSignInIdentity
    func signOut()
    func disconnect() async throws
}

/// Live GoogleSignIn 9.2 adapter. It is the only session component that knows
/// about SDK user/result types; callers receive immutable app-owned values.
@MainActor
final class SystemGoogleSignInProvider: GoogleSignInProviding {
    var hasPreviousSignIn: Bool {
        GIDSignIn.sharedInstance.hasPreviousSignIn()
    }

    func restorePreviousSignIn() async throws -> GoogleSignInIdentity {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return try Self.identity(from: user)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func signIn(
        presenting viewController: UIViewController,
        additionalScopes: [String]
    ) async throws -> GoogleSignInIdentity {
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: additionalScopes
            )
            return try Self.identity(from: result.user)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func disconnect() async throws {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                GIDSignIn.sharedInstance.disconnect { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            throw Self.failure(from: error)
        }
    }

    private static func identity(from user: GIDGoogleUser) throws -> GoogleSignInIdentity {
        guard let stableUserID = nonEmpty(user.userID),
              let email = nonEmpty(user.profile?.email) else {
            throw GoogleSignInProviderFailure.invalidIdentity
        }
        return GoogleSignInIdentity(
            stableUserID: stableUserID,
            email: email,
            grantedScopes: Set(user.grantedScopes ?? [])
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func failure(from error: Error) -> GoogleSignInProviderFailure {
        if let failure = error as? GoogleSignInProviderFailure {
            return failure
        }
        let error = error as NSError
        guard error.domain == kGIDSignInErrorDomain else { return .unavailable }
        switch error.code {
        case GIDSignInError.canceled.rawValue:
            return .cancelled
        case GIDSignInError.hasNoAuthInKeychain.rawValue:
            return .noPreviousSignIn
        case GIDSignInError.refreshTokenExpired.rawValue:
            return .reconnectRequired
        default:
            return .unavailable
        }
    }
}
