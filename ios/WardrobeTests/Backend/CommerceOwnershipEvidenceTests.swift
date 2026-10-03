import CryptoKit
import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct CommerceOwnershipEvidenceTests {
    private struct Vector: Decodable {
        let challengeId: UUID
        let nonceHex: String
        let installationId: UUID
        let keyIdBase64: String
        let bindingRevision: Int64
        let issuedAtMs: Int64
        let expiresAtMs: Int64
        let appJws: String
        let deviceId: UUID
        let deviceNonce: UUID
        let deviceDigestHex: String
        let transcript: String
        let transcriptSha256: String

        func challenge(revision: Int64? = nil, lifetime: Int64? = nil) throws -> CommerceProofChallenge {
            CommerceProofChallenge(
                challengeID: challengeId, nonce: try CommerceOwnershipEvidenceTests.unhex(nonceHex),
                installationID: installationId, keyID: try #require(Data(base64Encoded: keyIdBase64)),
                bindingRevision: revision ?? bindingRevision, issuedAtMS: issuedAtMs,
                expiresAtMS: lifetime.map { issuedAtMs + $0 } ?? expiresAtMs
            )
        }
    }

    private struct FakeSource: StoreKitAppEvidenceSource {
        let result: Result<LocalAppTransactionSnapshot, CommerceEvidenceError>
        func currentSnapshot() async throws -> LocalAppTransactionSnapshot { try result.get() }
    }

    private func vector() throws -> Vector {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("shared/fixtures/commerce-app-proof.json"))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Vector.self, from: data)
    }

    nonisolated private static func unhex(_ value: String) throws -> Data {
        var result = Data()
        for offset in stride(from: 0, to: value.count, by: 2) {
            let first = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(first, offsetBy: 2)
            result.append(try #require(UInt8(value[first..<end], radix: 16)))
        }
        return result
    }

    private func snapshot() throws -> LocalAppTransactionSnapshot {
        let v = try vector()
        return LocalAppTransactionSnapshot(
            appJWS: v.appJws, deviceID: v.deviceId, deviceNonce: v.deviceNonce,
            deviceVerification: try Self.unhex(v.deviceDigestHex)
        )
    }

    @Test func sharedTranscriptAndAppleDeviceHashMatch() throws {
        let v = try vector()
        let bytes = try CommerceProofTranscript.bytes(
            challenge: v.challenge(), appJWS: v.appJws, deviceID: v.deviceId
        )
        #expect(bytes == Data(v.transcript.utf8))
        #expect(Data(SHA256.hash(data: bytes)) == (try Self.unhex(v.transcriptSha256)))
        #expect(try CommerceProofTranscript.deviceDigest(nonce: v.deviceNonce, deviceID: v.deviceId)
                == Self.unhex(v.deviceDigestHex))
    }

    @Test func revisionAndEvidenceAreBoundIntoDifferentTranscripts() throws {
        let v = try vector()
        let original = Data(v.transcript.utf8)
        #expect(try CommerceProofTranscript.bytes(
            challenge: v.challenge(revision: 8), appJWS: v.appJws, deviceID: v.deviceId
        ) != original)
        #expect(try CommerceProofTranscript.bytes(
            challenge: v.challenge(), appJWS: v.appJws + "x", deviceID: v.deviceId
        ) != original)
        #expect(try CommerceProofTranscript.bytes(
            challenge: v.challenge(), appJWS: v.appJws, deviceID: UUID()
        ) != original)
    }

    @Test(arguments: [Int64(-1), Int64(9_007_199_254_740_992)])
    func invalidRevisionRejected(_ revision: Int64) throws {
        let v = try vector()
        #expect(throws: CommerceEvidenceError.invalidInput) {
            try CommerceProofTranscript.bytes(
                challenge: v.challenge(revision: revision), appJWS: v.appJws, deviceID: v.deviceId
            )
        }
    }

    @Test(arguments: [Int64(-1), Int64(0), Int64(300_001)])
    func invalidLifetimeRejected(_ lifetime: Int64) throws {
        let v = try vector()
        #expect(throws: CommerceEvidenceError.invalidInput) {
            try CommerceProofTranscript.bytes(
                challenge: v.challenge(lifetime: lifetime), appJWS: v.appJws, deviceID: v.deviceId
            )
        }
    }

    @Test(arguments: ["", "é", String(repeating: "x", count: 32_769)])
    func invalidJWSShapeRejected(_ jws: String) throws {
        let v = try vector()
        #expect(throws: CommerceEvidenceError.invalidInput) {
            try CommerceProofTranscript.bytes(challenge: v.challenge(), appJWS: jws, deviceID: v.deviceId)
        }
    }

    @Test func collectorAcceptsLocallyMatchingEvidenceWithoutPurchase() async throws {
        let value = try snapshot()
        let result = try await CommerceOwnershipCollector.collect(from: FakeSource(result: .success(value)))
        #expect(result.appJWS == value.appJWS && result.deviceID == value.deviceID)
        #expect(!String(describing: result).contains(value.appJWS))
        #expect(!String(reflecting: result).contains(value.deviceID.uuidString))
    }

    @Test func collectorRejectsAnotherDevicesEvidence() async throws {
        let value = try snapshot()
        let other = LocalAppTransactionSnapshot(
            appJWS: value.appJWS, deviceID: UUID(), deviceNonce: value.deviceNonce,
            deviceVerification: value.deviceVerification
        )
        await #expect(throws: CommerceEvidenceError.deviceMismatch) {
            try await CommerceOwnershipCollector.collect(from: FakeSource(result: .success(other)))
        }
    }

    @Test(arguments: [CommerceEvidenceError.unavailableDeviceID, .unverifiedTransaction,
                      .unsupportedEnvironment, .deviceChanged])
    func collectorFailsClosedOnSourceError(_ error: CommerceEvidenceError) async {
        await #expect(throws: error) {
            try await CommerceOwnershipCollector.collect(from: FakeSource(result: .failure(error)))
        }
    }
}
