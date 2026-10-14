import CryptoKit
import Foundation
import StoreKit

enum CommerceEvidenceError: Error, Equatable {
    case invalidInput
    case unverifiedTransaction
    case unavailableDeviceID
    case deviceChanged
    case deviceMismatch
    case unsupportedEnvironment
    case expiredChallenge
}

/// Inactive protocol draft. No route issues or consumes this challenge.
/// Server persistence must consume it with the App Attest counter.
struct CommerceProofChallenge: Sendable {
    let challengeID: UUID
    let nonce: Data
    let installationID: UUID
    let keyID: Data
    let bindingRevision: Int64
    let issuedAtMS: Int64
    let expiresAtMS: Int64

    func validate() throws {
        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        guard challengeID != zero, installationID != zero,
              nonce.count == 32, keyID.count == 32,
              (0...9_007_199_254_740_991).contains(bindingRevision),
              (0...253_402_300_799_999).contains(issuedAtMS),
              expiresAtMS > issuedAtMS, expiresAtMS <= 253_402_300_799_999,
              expiresAtMS - issuedAtMS <= 300_000 else {
            throw CommerceEvidenceError.invalidInput
        }
    }

    func requireFresh(at date: Date, notBefore floor: Date) throws {
        try validate()
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite, floor.timeIntervalSince1970.isFinite,
              date >= floor, milliseconds >= Double(issuedAtMS),
              milliseconds < Double(expiresAtMS) else {
            throw CommerceEvidenceError.expiredChallenge
        }
    }
}

enum CommerceProofTranscript {
    static let domain = "wardrobe-commerce-app-proof-v1"
    private static let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static func deviceDigest(nonce: UUID, deviceID: UUID) throws -> Data {
        guard nonce != zeroUUID, deviceID != zeroUUID else {
            throw CommerceEvidenceError.invalidInput
        }
        let input = nonce.uuidString.lowercased() + deviceID.uuidString.lowercased()
        return Data(SHA384.hash(data: Data(input.utf8)))
    }

    static func bytes(
        challenge: CommerceProofChallenge, appJWS: String, deviceID: UUID
    ) throws -> Data {
        try challenge.validate()
        guard deviceID != zeroUUID,
              (1...32_768).contains(appJWS.utf8.count),
              appJWS.utf8.allSatisfy({ $0 < 128 }) else {
            throw CommerceEvidenceError.invalidInput
        }
        let fields = [
            domain, challenge.challengeID.uuidString.lowercased(), hex(challenge.nonce),
            challenge.installationID.uuidString.lowercased(), hex(challenge.keyID),
            String(challenge.bindingRevision), String(challenge.issuedAtMS),
            String(challenge.expiresAtMS), hex(Data(SHA256.hash(data: Data(appJWS.utf8)))),
            deviceID.uuidString.lowercased()
        ]
        return Data((fields.joined(separator: "\n") + "\n").utf8)
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

/// A trusted in-process adapter supplies this only after StoreKit verification.
/// It is a testing seam, not an input type accepted from a URL, file or server.
struct LocalAppTransactionSnapshot: Sendable {
    let appJWS: String
    let deviceID: UUID
    let deviceNonce: UUID
    let deviceVerification: Data
}

@MainActor
protocol StoreKitAppEvidenceSource {
    func currentSnapshot() async throws -> LocalAppTransactionSnapshot
}

@MainActor
struct SystemStoreKitAppEvidenceSource: StoreKitAppEvidenceSource {
    func currentSnapshot() async throws -> LocalAppTransactionSnapshot {
        guard let before = AppStore.deviceVerificationID else {
            throw CommerceEvidenceError.unavailableDeviceID
        }
        let result = try await AppTransaction.shared
        guard case .verified(let transaction) = result else {
            throw CommerceEvidenceError.unverifiedTransaction
        }
        guard transaction.environment == .production || transaction.environment == .sandbox else {
            throw CommerceEvidenceError.unsupportedEnvironment
        }
        guard let after = AppStore.deviceVerificationID else {
            throw CommerceEvidenceError.unavailableDeviceID
        }
        guard before == after else { throw CommerceEvidenceError.deviceChanged }
        // Never call refresh() automatically: Apple says it prompts for App Store
        // authentication and must follow an explicit user action.
        return LocalAppTransactionSnapshot(
            appJWS: result.jwsRepresentation, deviceID: after,
            deviceNonce: transaction.deviceVerificationNonce,
            deviceVerification: transaction.deviceVerification
        )
    }
}

struct CollectedAppEvidence: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let appJWS: String
    let deviceID: UUID
    var description: String { "CollectedAppEvidence(redacted)" }
    var debugDescription: String { description }

    fileprivate init(appJWS: String, deviceID: UUID) {
        self.appJWS = appJWS
        self.deviceID = deviceID
    }
}

/// Volatile, unsubmitted proof. It grants no ownership and must never be logged
/// or persisted. The future transport must recheck identity and server admission.
struct SignedCommerceAppProof: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let challengeID: UUID
    let appJWS: String
    let deviceID: UUID
    let assertionObject: Data
    var description: String { "SignedCommerceAppProof(redacted)" }
    var debugDescription: String { description }
}

/// Called only by the inactive collect-and-sign operation and tests. No product
/// caller, storage or commerce HTTP request is installed.
/// A local comparison is not an independently authenticated server device identity.
@MainActor
enum CommerceOwnershipCollector {
    static func collect(
        from source: any StoreKitAppEvidenceSource = SystemStoreKitAppEvidenceSource()
    ) async throws -> CollectedAppEvidence {
        let snapshot = try await source.currentSnapshot()
        guard (1...32_768).contains(snapshot.appJWS.utf8.count),
              snapshot.appJWS.utf8.allSatisfy({ $0 < 128 }) else {
            throw CommerceEvidenceError.invalidInput
        }
        let expected = try CommerceProofTranscript.deviceDigest(
            nonce: snapshot.deviceNonce, deviceID: snapshot.deviceID
        )
        guard snapshot.deviceVerification == expected else {
            throw CommerceEvidenceError.deviceMismatch
        }
        return CollectedAppEvidence(appJWS: snapshot.appJWS, deviceID: snapshot.deviceID)
    }
}
