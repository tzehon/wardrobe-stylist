import CryptoKit
import DeviceCheck
import Foundation
import Testing

@testable import Wardrobe

@Suite(.serialized)
struct AppAttestAuthorizationTests {
    private let baseURL = URL(string: "https://backend.example")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func enrollsANewInstallationAndCachesTheShortLivedSession() async throws {
        let challenge = Data(repeating: 0x1a, count: 32)
        let newKeyID = Self.keyID(byte: 0x11)
        let service = FakeAppAttestService(
            generatedKeyID: newKeyID,
            attestation: Data([0xaa, 0xbb]),
            assertion: Data([0xcc])
        )
        let store = FakeAppAttestCredentialStore()
        let sessionToken = Self.sessionToken("session-one")
        installAuthHandler(challenges: [challenge], tokens: [sessionToken])
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let first = try await authorization.accessToken(rejecting: nil)
        let second = try await authorization.accessToken(rejecting: nil)

        #expect(first == sessionToken)
        #expect(second == sessionToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/register",
        ])

        let challengeBody = try jsonBody(at: 0)
        #expect(challengeBody["purpose"] as? String == "attestation")
        #expect(challengeBody["key_id"] == nil)
        let registrationBody = try jsonBody(at: 1)
        #expect(registrationBody["challenge_id"] as? String == "challenge-0")
        #expect(registrationBody["key_id"] as? String == newKeyID)
        #expect(registrationBody["attestation_object"] as? String == "qrs=")

        let attestationHashes = await service.attestationHashes
        #expect(attestationHashes == [Data(SHA256.hash(data: challenge))])
        let stored = await store.credential
        #expect(stored == AppAttestCredential(
            keyID: newKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
    }

    @Test func registeredInstallationSignsAndSendsTheExactClientData() async throws {
        let challenge = Data(repeating: 0x2b, count: 32)
        // 0xfb produces both "/" and "+" in standard Base64, so the byte
        // vector proves Swift did not escape slashes or switch alphabets.
        let registeredKeyID = Self.keyID(byte: 0xfb)
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data([0xaa]),
            assertion: Data([0xde, 0xad])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let sessionToken = Self.sessionToken("asserted-session")
        installAuthHandler(challenges: [challenge], tokens: [sessionToken])
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        let challengeBody = try jsonBody(at: 0)
        #expect(challengeBody["purpose"] as? String == "assertion")
        #expect(challengeBody["key_id"] as? String == registeredKeyID)

        let sessionBody = try jsonBody(at: 1)
        #expect(sessionBody["assertion_object"] as? String == "3q0=")
        let encodedClientData = try #require(sessionBody["client_data"] as? String)
        let clientData = try #require(Data(base64Encoded: encodedClientData))
        let expectedClientData = Data(
            #"{"challenge":"\#(base64URL(challenge))","challenge_id":"challenge-0","key_id":"\#(registeredKeyID)","purpose":"assertion","version":1}"#.utf8
        )
        #expect(clientData == expectedClientData)
        let clientJSON = try #require(
            JSONSerialization.jsonObject(with: clientData) as? [String: Any]
        )
        #expect(clientJSON["challenge"] as? String == base64URL(challenge))
        #expect(clientJSON["challenge_id"] as? String == "challenge-0")
        #expect(clientJSON["key_id"] as? String == registeredKeyID)
        #expect(clientJSON["purpose"] as? String == "assertion")
        #expect(clientJSON["version"] as? Int == 1)
        let assertionHashes = await service.assertionHashes
        #expect(assertionHashes == [Data(SHA256.hash(data: clientData))])
    }

    @Test func deletesTheFreshlyProvenIdentityAndClearsLocalAuthorization() async throws {
        let keyID = Self.keyID(byte: 0x71)
        let credential = AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd1])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        let challenge = Data(repeating: 0x72, count: 32)
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"deletion-proof","challenge":"\#(Self.base64URL(challenge))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected deletion path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.deleteServerIdentity() == .deleted)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
        ])

        let challengeBody = try jsonBody(at: 0)
        #expect(challengeBody["purpose"] as? String == "deletion")
        #expect(challengeBody["key_id"] as? String == keyID)
        let deletionBody = try jsonBody(at: 1)
        #expect(deletionBody["key_id"] as? String == keyID)
        #expect(deletionBody["assertion_object"] as? String == "0Q==")
        let encodedClientData = try #require(deletionBody["client_data"] as? String)
        let clientData = try #require(Data(base64Encoded: encodedClientData))
        let expectedClientData = Data(
            #"{"challenge":"\#(Self.base64URL(challenge))","challenge_id":"deletion-proof","key_id":"\#(keyID)","purpose":"deletion","version":1}"#.utf8
        )
        #expect(clientData == expectedClientData)
        #expect(await service.assertionHashes == [Data(SHA256.hash(data: clientData))])
    }

    @Test func maintenancePendingDeletionPreservesCredentialButFencesAuthorization() async throws {
        let keyID = Self.keyID(byte: 0x73)
        let credential = AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd2])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        let token = Self.sessionToken("preserved-session")
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"transient-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: 0x74, count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (
                    Self.response(503, request: request),
                    Data(#"{"detail":{"code":"deletion_maintenance_pending"}}"#.utf8)
                )
            default:
                Issue.record("Unexpected transient-deletion path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        await #expect(throws: AppAttestAuthorizationError.http(
            status: 503,
            code: "deletion_maintenance_pending"
        )) {
            _ = try await authorization.deleteServerIdentity()
        }
        #expect(await store.credential == credential)
        #expect(await store.removeCount == 0)
        let requestsAfterDeletion = URLProtocolStub.captured.count
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        await #expect(throws: AppAttestAuthorizationError.deletionConfirmationPending) {
            _ = try await authorization.accessToken(rejecting: nil)
        }
        #expect(URLProtocolStub.captured.count == requestsAfterDeletion)
        #expect(await service.generatedKeyCount == 0)
    }

    @Test func lostDeletionResponsePreservesCredentialButFencesAuthorization() async throws {
        let keyID = Self.keyID(byte: 0x74)
        let credential = AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd3])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        let token = Self.sessionToken("lost-deletion-response")
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"lost-response-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: 0x75, count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                throw URLError(.timedOut)
            default:
                Issue.record("Unexpected lost-response deletion path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        await #expect(throws: AppAttestAuthorizationError.network(.timedOut)) {
            _ = try await authorization.deleteServerIdentity()
        }
        #expect(await store.credential == credential)
        #expect(await store.removeCount == 0)
        let requestsAfterDeletion = URLProtocolStub.captured.count
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        await #expect(throws: AppAttestAuthorizationError.deletionConfirmationPending) {
            _ = try await authorization.accessToken(rejecting: nil)
        }
        #expect(URLProtocolStub.captured.count == requestsAfterDeletion)
        #expect(await service.generatedKeyCount == 0)
    }

    @Test func successfulDeletionRetiresLate401BearerBeforeExplicitReenrollment() async throws {
        let originalKeyID = Self.keyID(byte: 0xb1)
        let replacementKeyID = Self.keyID(byte: 0xb2)
        let oldToken = Self.sessionToken("pre-deletion-session")
        let replacementToken = Self.sessionToken("post-deletion-session")
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xb3]),
            assertion: Data([0xb4])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: originalKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"retirement-\#(index)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0xb5 + index), count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(oldToken)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            case "/auth/app-attest/register":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(replacementToken)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"20000000-0000-0000-0000-000000000002"}"#.utf8)
                )
            default:
                Issue.record("Unexpected retired-session path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == oldToken)
        #expect(try await authorization.deleteServerIdentity() == .deleted)
        let requestsAfterDeletion = URLProtocolStub.captured.count

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: oldToken)
        }
        #expect(URLProtocolStub.captured.count == requestsAfterDeletion)
        #expect(await service.generatedKeyCount == 0)

        #expect(try await authorization.accessToken(rejecting: nil) == replacementToken)
        #expect(await service.generatedKeyCount == 1)
        let requestsAfterExplicitReenrollment = URLProtocolStub.captured.count
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: oldToken)
        }
        #expect(URLProtocolStub.captured.count == requestsAfterExplicitReenrollment)
        #expect(try await authorization.accessToken(rejecting: nil) == replacementToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
            "/auth/app-attest/challenge",
            "/auth/app-attest/register",
        ])
    }

    @Test func definitiveDeletionRetiresBearerBeforeKeychainRemovalFailure() async throws {
        let keyID = Self.keyID(byte: 0xb7)
        let token = Self.sessionToken("remove-failure-session")
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xb8])
        )
        let store = FakeAppAttestCredentialStore(
            credential: AppAttestCredential(
                keyID: keyID,
                isRegistered: true,
                pendingEnrollment: nil
            ),
            removeError: .invalidCredentialStorage
        )
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                defer { challengeIndex += 1 }
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"remove-failure-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: 0xb9, count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected removal-failure path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        await #expect(throws: AppAttestAuthorizationError.invalidCredentialStorage) {
            _ = try await authorization.deleteServerIdentity()
        }
        let requestsAfterDeletion = URLProtocolStub.captured.count

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        #expect(URLProtocolStub.captured.count == requestsAfterDeletion)
        #expect(await service.generatedKeyCount == 0)
        #expect(await store.credential?.keyID == keyID)
        #expect(await store.removeCount == 1)
    }

    @Test func deletionFencesARequestThatReturnsJustAfterBearerExpiration() async throws {
        let keyID = Self.keyID(byte: 0xc1)
        let token = Self.sessionToken("expiry-race-session")
        let clock = LockedTestDate(now)
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xc2])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installDeletionRaceHandler(token: token)
        defer { URLProtocolStub.reset() }

        let authorization = AppAttestAuthorization(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            service: service,
            credentialStore: store,
            now: { clock.value }
        )
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        clock.advance(by: 899)
        #expect(try await authorization.deleteServerIdentity() == .deleted)
        let requestCount = URLProtocolStub.captured.count

        clock.advance(by: 2)
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        #expect(URLProtocolStub.captured.count == requestCount)
    }

    @Test func deletionJustAfterExpirationStillFencesAnInFlightBearer() async throws {
        let keyID = Self.keyID(byte: 0xc3)
        let token = Self.sessionToken("post-expiry-deletion")
        let clock = LockedTestDate(now)
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xc4])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installDeletionRaceHandler(token: token)
        defer { URLProtocolStub.reset() }

        let authorization = AppAttestAuthorization(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            service: service,
            credentialStore: store,
            now: { clock.value }
        )
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        clock.advance(by: 901)
        #expect(try await authorization.deleteServerIdentity() == .deleted)
        let requestCount = URLProtocolStub.captured.count

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        #expect(URLProtocolStub.captured.count == requestCount)
    }

    @Test func retiredBearerDigestPersistsForTheRemainingProcessLifetime() async throws {
        let originalKeyID = Self.keyID(byte: 0xc5)
        let replacementKeyID = Self.keyID(byte: 0xc6)
        let token = Self.sessionToken("process-lifetime-session")
        let clock = LockedTestDate(now)
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xc7]),
            assertion: Data([0xc8])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: originalKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                defer { challengeIndex += 1 }
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"grace-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0xc9 + challengeIndex), count: 32)))","expires_at":"2027-01-15T08:45:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:45:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected process-lifetime retirement path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = AppAttestAuthorization(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            service: service,
            credentialStore: store,
            now: { clock.value }
        )
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        clock.advance(by: 901)
        #expect(try await authorization.deleteServerIdentity() == .deleted)
        let requestCountAfterDeletion = URLProtocolStub.captured.count
        clock.advance(by: 7 * 24 * 60 * 60)

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        #expect(URLProtocolStub.captured.count == requestCountAfterDeletion)
        #expect(await service.generatedKeyCount == 0)
    }

    @Test func onlyGuaranteedAbsentClearsTheCredentialWithoutAProof() async throws {
        let credential = AppAttestCredential(
            keyID: Self.keyID(byte: 0x75),
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd3])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        URLProtocolStub.install { request in
            (
                Self.response(401, request: request),
                Data(#"{"detail":{"code":"unknown_app_attest_key"}}"#.utf8)
            )
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.deleteServerIdentity() == .alreadyAbsent)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(await service.assertionHashes.isEmpty)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
        ])
    }

    @Test func deletionThatLosesToCleanupClearsAndFencesThePriorBearer() async throws {
        let credential = AppAttestCredential(
            keyID: Self.keyID(byte: 0x91),
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x92])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        let token = Self.sessionToken("cleanup-race-session")
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"cleanup-race-\#(index)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0x93 + index), count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (
                    Self.response(401, request: request),
                    Data(#"{"detail":{"code":"unknown_app_attest_key"}}"#.utf8)
                )
            default:
                Issue.record("Unexpected cleanup-race deletion path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == token)
        #expect(try await authorization.deleteServerIdentity() == .alreadyAbsent)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        let requestCountAfterDeletion = URLProtocolStub.captured.count

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: token)
        }
        #expect(URLProtocolStub.captured.count == requestCountAfterDeletion)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
        ])
    }

    @Test func configurationMismatchDoesNotClearTheCredential() async {
        let credential = AppAttestCredential(
            keyID: Self.keyID(byte: 0x76),
            isRegistered: true,
            pendingEnrollment: nil
        )
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd4])
        )
        let store = FakeAppAttestCredentialStore(credential: credential)
        URLProtocolStub.install { request in
            (
                Self.response(401, request: request),
                Data(#"{"detail":{"code":"configuration_mismatch"}}"#.utf8)
            )
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        await #expect(throws: AppAttestAuthorizationError.http(
            status: 401,
            code: "configuration_mismatch"
        )) {
            _ = try await authorization.deleteServerIdentity()
        }
        #expect(await store.credential == credential)
        #expect(await store.removeCount == 0)
    }

    @Test func permanentlyInvalidDeletionKeyFallsBackToInactivityExpiry() async throws {
        let invalidKey = NSError(
            domain: DCError.errorDomain,
            code: DCError.Code.invalidKey.rawValue
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: Self.keyID(byte: 0xba),
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data(),
            assertionError: invalidKey
        )
        URLProtocolStub.install { request in
            (
                Self.response(200, request: request),
                Data(#"{"challenge_id":"invalid-deletion-key","challenge":"\#(Self.base64URL(Data(repeating: 0xbb, count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
            )
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.deleteServerIdentity() == .noVerifiableIdentity)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
        ])
    }

    @Test func missingCredentialDoesNotClaimAnInaccessibleIdentityWasDeleted() async throws {
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore()
        URLProtocolStub.install { _ in
            Issue.record("A missing credential cannot authenticate a server deletion")
            throw URLError(.badServerResponse)
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.deleteServerIdentity() == .noVerifiableIdentity)
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(await store.removeCount == 0)
    }

    @Test func malformedCredentialFallsBackToInactivityExpiryWithoutNetwork() async throws {
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: "not-a-canonical-app-attest-key",
            isRegistered: true,
            pendingEnrollment: nil
        ))
        URLProtocolStub.install { _ in
            Issue.record("A malformed credential cannot authenticate a deletion")
            throw URLError(.badServerResponse)
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.deleteServerIdentity() == .noVerifiableIdentity)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(URLProtocolStub.captured.isEmpty)
    }

    @Test func missingCredentialAlsoInvalidatesAMemoryOnlyCachedSession() async throws {
        let originalKeyID = Self.keyID(byte: 0xa1)
        let replacementKeyID = Self.keyID(byte: 0xa2)
        let oldToken = Self.sessionToken("inaccessible-session")
        let replacementToken = Self.sessionToken("replacement-session")
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xa3]),
            assertion: Data([0xa4])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: originalKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                defer { challengeIndex += 1 }
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"missing-credential-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0xa5 + challengeIndex), count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(oldToken)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/register":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(replacementToken)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"20000000-0000-0000-0000-000000000002"}"#.utf8)
                )
            default:
                Issue.record("Unexpected missing-credential path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == oldToken)
        await store.discardCredentialExternally()
        let requestsBeforeDeletion = URLProtocolStub.captured.count

        #expect(try await authorization.deleteServerIdentity() == .noVerifiableIdentity)
        #expect(URLProtocolStub.captured.count == requestsBeforeDeletion)
        #expect(await store.removeCount == 0)

        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await authorization.accessToken(rejecting: oldToken)
        }
        #expect(URLProtocolStub.captured.count == requestsBeforeDeletion)

        let tokenAfterDeletion = try await authorization.accessToken(rejecting: nil)
        #expect(tokenAfterDeletion == replacementToken)
        #expect(tokenAfterDeletion != oldToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/register",
        ])
    }

    @Test func deletionDrainsAnInFlightSessionBeforeSigningItsFreshProof() async throws {
        let keyID = Self.keyID(byte: 0x77)
        let assertionGate = OneShotAsyncGate()
        let flightProbe = SessionFlightProbe()
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xd5]),
            assertionGate: assertionGate
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let token = Self.sessionToken("drained-session")
        let challenges = [
            Data(repeating: 0x78, count: 32),
            Data(repeating: 0x79, count: 32),
        ]
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"drain-\#(index)","challenge":"\#(Self.base64URL(challenges[index]))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected drain-deletion path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(
            service: service,
            store: store,
            sessionFlightObserver: flightProbe
        )
        let session = Task { try await authorization.accessToken(rejecting: nil) }
        await assertionGate.waitUntilArrived()

        let deletion = Task { try await authorization.deleteServerIdentity() }
        await flightProbe.waitUntilDeletionDrain()
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
        ])

        await assertionGate.release()
        await #expect(throws: AppAttestAuthorizationError.deletionInProgress) {
            _ = try await session.value
        }
        #expect(try await deletion.value == .deleted)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
        ])
        #expect(await service.assertionHashes.count == 2)
    }

    @Test func deletionPreventsInvalidKeyRefreshFromReplacingTheConfirmedIdentity() async throws {
        let keyID = Self.keyID(byte: 0x7a)
        let invalidKey = NSError(
            domain: DCError.errorDomain,
            code: DCError.Code.invalidKey.rawValue
        )
        let assertionGate = OneShotAsyncGate()
        let flightProbe = SessionFlightProbe()
        let service = FakeAppAttestService(
            generatedKeyID: Self.keyID(byte: 0x7b),
            attestation: Data([0x7b]),
            assertion: Data([0x7a]),
            assertionError: invalidKey,
            assertionErrorOccurrences: 1,
            assertionGate: assertionGate
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"invalid-key-race-\#(index)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0x7a + index), count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected invalid-key deletion race path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(
            service: service,
            store: store,
            sessionFlightObserver: flightProbe
        )
        let session = Task { try await authorization.accessToken(rejecting: nil) }
        await assertionGate.waitUntilArrived()

        let deletion = Task { try await authorization.deleteServerIdentity() }
        await flightProbe.waitUntilDeletionDrain()
        await assertionGate.release()

        await #expect(throws: AppAttestAuthorizationError.deletionInProgress) {
            _ = try await session.value
        }
        #expect(try await deletion.value == .deleted)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(await service.generatedKeyCount == 0)
        #expect(await service.assertionHashes.count == 2)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
        ])
    }

    @Test func deletionPreventsRevokedRefreshFromReplacingTheConfirmedIdentity() async throws {
        let keyID = Self.keyID(byte: 0x7c)
        let assertionGate = OneShotAsyncGate()
        let flightProbe = SessionFlightProbe()
        let service = FakeAppAttestService(
            generatedKeyID: Self.keyID(byte: 0x7d),
            attestation: Data([0x7d]),
            assertion: Data([0x7c]),
            assertionGate: assertionGate
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: keyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"revoked-key-race-\#(index)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0x7c + index), count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(401, request: request),
                    Data(#"{"detail":{"code":"revoked_app_attest_key","message":"Unavailable"}}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected revoked-key deletion race path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(
            service: service,
            store: store,
            sessionFlightObserver: flightProbe
        )
        let session = Task { try await authorization.accessToken(rejecting: nil) }
        await assertionGate.waitUntilArrived()

        let deletion = Task { try await authorization.deleteServerIdentity() }
        await flightProbe.waitUntilDeletionDrain()
        await assertionGate.release()

        await #expect(throws: AppAttestAuthorizationError.deletionInProgress) {
            _ = try await session.value
        }
        #expect(try await deletion.value == .deleted)
        #expect(await store.credential == nil)
        #expect(await store.removeCount == 1)
        #expect(await service.generatedKeyCount == 0)
        #expect(await service.assertionHashes.count == 2)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/delete",
        ])
    }

    @Test func concurrentCallersShareOneAssertionAndSessionRefresh() async throws {
        let registeredKeyID = Self.keyID(byte: 0x2c)
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xca, 0xfe]),
            assertionDelay: .milliseconds(50)
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let sessionToken = Self.sessionToken("shared-session")
        installAuthHandler(
            challenges: [Data(repeating: 0x2d, count: 32)],
            tokens: [sessionToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        async let first = authorization.accessToken(rejecting: nil)
        async let second = authorization.accessToken(rejecting: nil)
        let (firstToken, secondToken) = try await (first, second)

        #expect(firstToken == sessionToken)
        #expect(secondToken == sessionToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.assertionHashes.count == 1)
    }

    @Test func aRejectedInFlightResultStartsANewGenerationBeforeReturning() async throws {
        let registeredKeyID = Self.keyID(byte: 0x2e)
        let rejectedToken = Self.sessionToken("rejected-flight")
        let replacementToken = Self.sessionToken("replacement-flight")
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0xca, 0xfe])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(
            challenges: [
                Data(repeating: 0x2f, count: 32),
                Data(repeating: 0x30, count: 32),
            ],
            tokens: [rejectedToken, replacementToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: rejectedToken)

        #expect(token == replacementToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.assertionHashes.count == 2)
    }

    @Test func rejectedWaiterReplacesACompletedFlightBeforeItsCreatorFinalizes() async throws {
        let registeredKeyID = Self.keyID(byte: 0x36)
        let rejectedToken = Self.sessionToken("concurrent-rejected-flight")
        let replacementToken = Self.sessionToken("concurrent-replacement")
        let assertionGate = OneShotAsyncGate()
        let flightProbe = SessionFlightProbe()
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x36]),
            assertionGate: assertionGate
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(
            challenges: [
                Data(repeating: 0x37, count: 32),
                Data(repeating: 0x38, count: 32),
            ],
            tokens: [rejectedToken, replacementToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(
            service: service,
            store: store,
            sessionFlightObserver: flightProbe
        )
        let creator = Task {
            try await authorization.accessToken(rejecting: nil)
        }
        await assertionGate.waitUntilArrived()

        // This models a 401 retry arriving while another caller is already
        // refreshing. It must await that flight, but must not reuse X when the
        // shared flight happens to produce the rejected bearer X.
        let rejectedWaiter = Task {
            try await authorization.accessToken(rejecting: rejectedToken)
        }
        await flightProbe.waitUntilJoined()
        await assertionGate.release()
        await flightProbe.waitUntilFirstCreatorIsBlocked()

        let waiterResult = await rejectedWaiter.result
        await flightProbe.releaseFirstCreator()
        let creatorResult = await creator.result

        #expect(try waiterResult.get() == replacementToken)
        #expect(try creatorResult.get() == replacementToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.assertionHashes.count == 2)
    }

    @Test func repeatedRejectedBearerFailsAfterOneReplacementGeneration() async {
        let registeredKeyID = Self.keyID(byte: 0x39)
        let rejectedToken = Self.sessionToken("repeated-rejected-flight")
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x39])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(
            challenges: [
                Data(repeating: 0x3a, count: 32),
                Data(repeating: 0x3b, count: 32),
            ],
            tokens: [rejectedToken, rejectedToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        await #expect(throws: AppAttestAuthorizationError.invalidResponse) {
            _ = try await authorization.accessToken(rejecting: rejectedToken)
        }

        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.assertionHashes.count == 2)
    }

    @Test func aStaleRejectionDoesNotInvalidateTheCurrentCachedSession() async throws {
        let registeredKeyID = Self.keyID(byte: 0x31)
        let currentToken = Self.sessionToken("current-session")
        let refreshedToken = Self.sessionToken("refreshed-session")
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x31])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: registeredKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(
            challenges: [
                Data(repeating: 0x32, count: 32),
                Data(repeating: 0x33, count: 32),
            ],
            tokens: [currentToken, refreshedToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == currentToken)
        #expect(
            try await authorization.accessToken(
                rejecting: Self.sessionToken("already-obsolete")
            ) == currentToken
        )
        #expect(URLProtocolStub.captured.count == 2)

        #expect(try await authorization.accessToken(rejecting: currentToken) == refreshedToken)
        #expect(URLProtocolStub.captured.count == 4)
    }

    @Test func rejectsUnsafeTokenAndInvalidSessionExpirationMetadata() async {
        struct InvalidSessionCase {
            let token: String
            let expiresIn: Int
            let expiresAt: String
        }
        let cases = [
            InvalidSessionCase(
                token: "unsafe token with spaces",
                expiresIn: 900,
                expiresAt: "2027-01-15T08:15:00Z"
            ),
            InvalidSessionCase(
                token: Self.sessionToken("above-policy-ttl"),
                expiresIn: 901,
                expiresAt: "2027-01-15T08:15:01Z"
            ),
            InvalidSessionCase(
                token: Self.sessionToken("malformed-date"),
                expiresIn: 900,
                expiresAt: "not-an-absolute-utc-date"
            ),
            InvalidSessionCase(
                token: Self.sessionToken("already-expired"),
                expiresIn: 900,
                expiresAt: "2027-01-15T07:59:59Z"
            ),
        ]

        for invalid in cases {
            let service = FakeAppAttestService(
                generatedKeyID: "unused",
                attestation: Data(),
                assertion: Data([0x34])
            )
            let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
                keyID: Self.keyID(byte: 0x34),
                isRegistered: true,
                pendingEnrollment: nil
            ))
            URLProtocolStub.install { request in
                switch request.url?.path {
                case "/auth/app-attest/challenge":
                    return (
                        Self.response(200, request: request),
                        Data(#"{"challenge_id":"invalid-session-metadata","challenge":"\#(base64URL(Data(repeating: 0x35, count: 32)))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                    )
                case "/auth/app-attest/session":
                    let body: [String: Any] = [
                        "access_token": invalid.token,
                        "token_type": "Bearer",
                        "expires_in": invalid.expiresIn,
                        "expires_at": invalid.expiresAt,
                        "installation_id": "10000000-0000-0000-0000-000000000001",
                    ]
                    return (
                        Self.response(200, request: request),
                        try JSONSerialization.data(withJSONObject: body)
                    )
                default:
                    Issue.record("Unexpected auth path")
                    return (Self.response(500, request: request), nil)
                }
            }

            let authorization = makeAuthorization(service: service, store: store)
            await #expect(throws: AppAttestAuthorizationError.invalidResponse) {
                _ = try await authorization.accessToken(rejecting: nil)
            }
            URLProtocolStub.reset()
        }
    }

    @Test func acceptsTheBackendMaximum900SecondSessionTTL() async throws {
        let token = Self.sessionToken("maximum-policy-ttl")
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x3a])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: Self.keyID(byte: 0x3a),
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(
            challenges: [Data(repeating: 0x3b, count: 32)],
            tokens: [token]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        #expect(try await authorization.accessToken(rejecting: nil) == token)
    }

    @Test func crossOrigin307DoesNotForwardAnAssertionOrClientData() async throws {
        let session = BackendHTTPSession.make()
        defer { session.invalidateAndCancel() }
        #expect(session.configuration.urlCache == nil)
        #expect(session.configuration.httpCookieStorage == nil)
        #expect(session.configuration.httpShouldSetCookies == false)
        #expect(session.configuration.urlCredentialStorage == nil)
        #expect(session.configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(session.configuration.timeoutIntervalForRequest == 30)
        #expect(session.configuration.timeoutIntervalForResource == 60)

        let originalURL = baseURL.appending(path: "auth/app-attest/session")
        let response = HTTPURLResponse(
            url: originalURL,
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "https://attacker.example/collect"]
        )!
        var proposed = URLRequest(url: URL(string: "https://attacker.example/collect")!)
        proposed.httpMethod = "POST"
        proposed.httpBody = Data(
            #"{"assertion_object":"private-proof","client_data":"private-client-data"}"#.utf8
        )

        // Pin both halves of the production wiring: the backend factory must
        // install the blocker, and that exact delegate path must refuse the
        // redirect rather than forwarding App Attest proof material.
        let delegate = try #require(session.delegate as? BackendRedirectBlocker)
        let task = session.dataTask(with: URLRequest(url: originalURL))
        defer { task.cancel() }
        let redirected: URLRequest? = await withCheckedContinuation { continuation in
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: proposed
            ) { request in
                continuation.resume(returning: request)
            }
        }

        #expect(redirected == nil)
        #expect(proposed.httpBody?.range(of: Data("private-proof".utf8)) != nil)
    }

    @Test func unsupportedDeviceFailsClosedBeforeNetworkOrKeyGeneration() async {
        let service = FakeAppAttestService(
            isSupported: false,
            generatedKeyID: "must-not-generate",
            attestation: Data(),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore()
        URLProtocolStub.install { _ in
            Issue.record("Unsupported devices must not reach the backend auth endpoints")
            throw URLError(.badServerResponse)
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        await #expect(throws: AppAttestAuthorizationError.unsupportedDevice) {
            _ = try await authorization.accessToken(rejecting: nil)
        }
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(await service.generatedKeyCount == 0)
        #expect(await store.credential == nil)
    }

    @Test func localizedErrorsKeepRemoteFailuresSafeAndActionable() {
        #expect(
            AppAttestAuthorizationError.unsupportedDevice.localizedDescription
                .contains("supported physical iPhone")
        )
        #expect(
            AppAttestAuthorizationError.unsupportedDevice.localizedDescription
                .contains("local wardrobe and Demo Mode still work")
        )
        #expect(
            AppAttestAuthorizationError.network(.notConnectedToInternet)
                .localizedDescription.contains("offline")
        )
        #expect(
            AppAttestAuthorizationError.http(status: 429, code: "rate_limited")
                .localizedDescription.contains("too many requests")
        )
        #expect(
            AppAttestAuthorizationError.serviceUnavailable.localizedDescription
                .contains("temporarily unavailable")
        )
        #expect(
            AppAttestAuthorizationError.retiredSession.localizedDescription
                .contains("identity was deleted")
        )
        #expect(
            AppAttestAuthorizationError.deletionConfirmationPending.localizedDescription
                .contains("Privacy & Data")
        )
    }

    @Test func rejectsAChallengeThatIsNotExactly32Bytes() async {
        let service = FakeAppAttestService(
            generatedKeyID: "unused",
            attestation: Data(),
            assertion: Data([0x01])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: Self.keyID(byte: 0x22),
            isRegistered: true,
            pendingEnrollment: nil
        ))
        installAuthHandler(challenges: [Data(repeating: 0x01, count: 16)], tokens: [])
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        await #expect(throws: AppAttestAuthorizationError.invalidChallenge) {
            _ = try await authorization.accessToken(rejecting: nil)
        }
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
        ])
        #expect(await service.assertionHashes.isEmpty)
    }

    @Test func staleRegisteredKeyAfterReinstallIsReplacedAndReenrolled() async throws {
        let oldChallenge = Data(repeating: 0x3c, count: 32)
        let newChallenge = Data(repeating: 0x4d, count: 32)
        let staleKeyID = Self.keyID(byte: 0x33)
        let replacementKeyID = Self.keyID(byte: 0x44)
        let invalidKey = NSError(
            domain: DCError.errorDomain,
            code: DCError.Code.invalidKey.rawValue
        )
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0x99]),
            assertion: Data(),
            assertionError: invalidKey
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: staleKeyID,
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let sessionToken = Self.sessionToken("replacement-session")
        installAuthHandler(
            challenges: [oldChallenge, newChallenge],
            tokens: [sessionToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/challenge",
            "/auth/app-attest/register",
        ])
        #expect(await service.generatedKeyCount == 1)
        #expect(await store.credential?.keyID == replacementKeyID)
        #expect(await store.credential?.isRegistered == true)
    }

    @Test func noncanonicalStoredKeyIsReplacedBeforeAnyAuthRequest() async throws {
        let replacementKeyID = Self.keyID(byte: 0x55)
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xaa]),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: "not-standard-base64url-or-padded",
            isRegistered: true,
            pendingEnrollment: nil
        ))
        let sessionToken = Self.sessionToken("replacement-session")
        installAuthHandler(
            challenges: [Data(repeating: 0x5d, count: 32)],
            tokens: [sessionToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/register",
        ])
        #expect(await store.credential?.keyID == replacementKeyID)
    }

    @Test func corruptStoredCredentialIsRemovedAndCleanlyReenrolled() async throws {
        let replacementKeyID = Self.keyID(byte: 0x5a)
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xab]),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore(
            loadError: .invalidCredentialStorage
        )
        let sessionToken = Self.sessionToken("recovered-session")
        installAuthHandler(
            challenges: [Data(repeating: 0x6d, count: 32)],
            tokens: [sessionToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(await store.removeCount == 1)
        #expect(await store.credential?.keyID == replacementKeyID)
        #expect(await store.credential?.isRegistered == true)
    }

    @Test func malformedPendingEnrollmentCannotTrapFutureRetries() async throws {
        let replacementKeyID = Self.keyID(byte: 0x5b)
        let service = FakeAppAttestService(
            generatedKeyID: replacementKeyID,
            attestation: Data([0xac]),
            assertion: Data()
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: Self.keyID(byte: 0x5c),
            isRegistered: false,
            pendingEnrollment: .init(
                challengeID: "damaged-pending-challenge",
                challenge: base64URL(Data(repeating: 0x01, count: 8)),
                expiresAt: "2027-01-15T08:00:00Z",
                attestationObject: nil
            )
        ))
        let sessionToken = Self.sessionToken("recovered-session")
        installAuthHandler(
            challenges: [Data(repeating: 0x6e, count: 32)],
            tokens: [sessionToken]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(await store.removeCount == 1)
        #expect(await store.credential?.keyID == replacementKeyID)
    }

    @Test func lostRegistrationResponseUsesAnAssertionInsteadOfReplacingTheValidKey() async throws {
        let challenge = Data(repeating: 0x5e, count: 32)
        let serverRegisteredKeyID = Self.keyID(byte: 0x66)
        let service = FakeAppAttestService(
            generatedKeyID: "must-not-generate",
            attestation: Data(),
            assertion: Data([0x77])
        )
        let store = FakeAppAttestCredentialStore(credential: AppAttestCredential(
            keyID: serverRegisteredKeyID,
            isRegistered: false,
            pendingEnrollment: .init(
                challengeID: "consumed-challenge",
                challenge: base64URL(Data(repeating: 0x01, count: 32)),
                expiresAt: "2027-01-15T08:00:00Z",
                attestationObject: "qg=="
            )
        ))
        let sessionToken = Self.sessionToken("proof-session")
        nonisolated(unsafe) var requestIndex = 0
        URLProtocolStub.install { request in
            requestIndex += 1
            switch request.url?.path {
            case "/auth/app-attest/register":
                return (
                    Self.response(409, request: request),
                    Data(#"{"detail":{"code":"app_attest_key_already_registered"}}"#.utf8)
                )
            case "/auth/app-attest/challenge":
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"assertion-challenge","challenge":"\#(base64URL(challenge))","expires_at":"2027-01-15T08:15:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(sessionToken)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            default:
                Issue.record("Unexpected path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == sessionToken)
        #expect(requestIndex == 3)
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/register",
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.generatedKeyCount == 0)
        #expect(await store.credential?.keyID == serverRegisteredKeyID)
        #expect(await store.credential?.isRegistered == true)
    }

    private func makeAuthorization(
        service: FakeAppAttestService,
        store: FakeAppAttestCredentialStore,
        sessionFlightObserver: (any AppAttestSessionFlightObserving)? = nil
    ) -> AppAttestAuthorization {
        AppAttestAuthorization(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            service: service,
            credentialStore: store,
            now: { now },
            sessionFlightObserver: sessionFlightObserver
        )
    }

    private func installAuthHandler(challenges: [Data], tokens: [String]) {
        nonisolated(unsafe) var challengeIndex = 0
        nonisolated(unsafe) var tokenIndex = 0
        URLProtocolStub.install { request in
            let body: String
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                guard challengeIndex < challenges.count else {
                    Issue.record("Received more auth challenges than expected")
                    return (Self.response(500, request: request), nil)
                }
                let index = challengeIndex
                challengeIndex += 1
                body = #"{"challenge_id":"challenge-\#(index)","challenge":"\#(base64URL(challenges[index]))","expires_at":"2027-01-15T08:15:00Z"}"#
            case "/auth/app-attest/register", "/auth/app-attest/session":
                guard tokenIndex < tokens.count else {
                    Issue.record("Received more auth session requests than expected")
                    return (Self.response(500, request: request), nil)
                }
                let token = tokens[tokenIndex]
                tokenIndex += 1
                body = #"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#
            default:
                Issue.record("Unexpected auth path: \(request.url?.path ?? "nil")")
                body = #"{"detail":{"code":"unexpected_path"}}"#
            }
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(body.utf8)
            )
        }
    }

    private func installDeletionRaceHandler(token: String) {
        nonisolated(unsafe) var challengeIndex = 0
        URLProtocolStub.install { request in
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                defer { challengeIndex += 1 }
                return (
                    Self.response(200, request: request),
                    Data(#"{"challenge_id":"expiry-race-\#(challengeIndex)","challenge":"\#(Self.base64URL(Data(repeating: UInt8(0xd0 + challengeIndex), count: 32)))","expires_at":"2027-01-15T08:45:00Z"}"#.utf8)
                )
            case "/auth/app-attest/session":
                return (
                    Self.response(200, request: request),
                    Data(#"{"access_token":"\#(token)","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:45:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            case "/auth/app-attest/delete":
                return (Self.response(204, request: request), nil)
            default:
                Issue.record("Unexpected expiry-race path")
                return (Self.response(500, request: request), nil)
            }
        }
    }

    private func jsonBody(at index: Int) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: URLProtocolStub.capturedBodies[index])
                as? [String: Any]
        )
    }

    private func base64URL(_ data: Data) -> String {
        Self.base64URL(data)
    }

    nonisolated private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated private static func keyID(byte: UInt8) -> String {
        Data(repeating: byte, count: 32).base64EncodedString()
    }

    nonisolated private static func sessionToken(_ label: String) -> String {
        var bytes = Data(label.utf8.prefix(32))
        bytes.append(Data(repeating: 0x2e, count: 32 - bytes.count))
        return base64URL(bytes)
    }

    nonisolated private static func response(
        _ status: Int,
        request: URLRequest
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

private final class LockedTestDate: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Date

    init(_ value: Date) {
        storedValue = value
    }

    var value: Date {
        lock.withLock { storedValue }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            storedValue = storedValue.addingTimeInterval(interval)
        }
    }
}

private actor FakeAppAttestCredentialStore: AppAttestCredentialStoring {
    var credential: AppAttestCredential?
    private var loadError: AppAttestAuthorizationError?
    private let removeError: AppAttestAuthorizationError?
    private(set) var removeCount = 0

    init(
        credential: AppAttestCredential? = nil,
        loadError: AppAttestAuthorizationError? = nil,
        removeError: AppAttestAuthorizationError? = nil
    ) {
        self.credential = credential
        self.loadError = loadError
        self.removeError = removeError
    }

    func load() throws -> AppAttestCredential? {
        if let loadError {
            self.loadError = nil
            throw loadError
        }
        return credential
    }

    func save(_ credential: AppAttestCredential) {
        self.credential = credential
    }

    func remove() throws {
        removeCount += 1
        if let removeError { throw removeError }
        credential = nil
    }

    func discardCredentialExternally() {
        credential = nil
    }
}

private actor FakeAppAttestService: AppAttestServicing {
    let supported: Bool
    let generatedKeyID: String
    let attestation: Data
    let assertion: Data
    let assertionError: (any Error)?
    let assertionErrorOccurrences: Int?
    let assertionDelay: Duration
    let assertionGate: OneShotAsyncGate?
    private(set) var generatedKeyCount = 0
    private(set) var attestationHashes: [Data] = []
    private(set) var assertionHashes: [Data] = []

    init(
        isSupported: Bool = true,
        generatedKeyID: String,
        attestation: Data,
        assertion: Data,
        assertionError: (any Error)? = nil,
        assertionErrorOccurrences: Int? = nil,
        assertionDelay: Duration = .zero,
        assertionGate: OneShotAsyncGate? = nil
    ) {
        supported = isSupported
        self.generatedKeyID = generatedKeyID
        self.attestation = attestation
        self.assertion = assertion
        self.assertionError = assertionError
        self.assertionErrorOccurrences = assertionErrorOccurrences
        self.assertionDelay = assertionDelay
        self.assertionGate = assertionGate
    }

    var isSupported: Bool { supported }

    func generateKey() -> String {
        generatedKeyCount += 1
        return generatedKeyID
    }

    func attestKey(_ keyID: String, clientDataHash: Data) -> Data {
        attestationHashes.append(clientDataHash)
        return attestation
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        assertionHashes.append(clientDataHash)
        if assertionHashes.count == 1, let assertionGate {
            await assertionGate.arriveAndWait()
        }
        if assertionDelay > .zero {
            try await Task.sleep(for: assertionDelay)
        }
        if let assertionError {
            let shouldThrow = assertionErrorOccurrences.map {
                assertionHashes.count <= $0
            } ?? true
            if shouldThrow { throw assertionError }
        }
        return assertion
    }
}

private actor OneShotAsyncGate {
    private var hasArrived = false
    private var isReleased = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func arriveAndWait() async {
        hasArrived = true
        let waiters = arrivalWaiters
        arrivalWaiters.removeAll()
        waiters.forEach { $0.resume() }

        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilArrived() async {
        guard !hasArrived else { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor SessionFlightProbe: AppAttestSessionFlightObserving {
    private var hasJoined = false
    private var joinWaiters: [CheckedContinuation<Void, Never>] = []
    private var isFirstCreatorBlocked = false
    private var firstCreatorWaiters: [CheckedContinuation<Void, Never>] = []
    private var noncreatorFinalizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstCreatorReleaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var deletionDrainStarted = false
    private var deletionDrainWaiters: [CheckedContinuation<Void, Never>] = []

    func didJoinSessionFlight() {
        hasJoined = true
        let waiters = joinWaiters
        joinWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func willFinalizeSessionFlight(createdByCaller: Bool) async {
        guard createdByCaller else {
            if !isFirstCreatorBlocked {
                await withCheckedContinuation { continuation in
                    noncreatorFinalizationWaiters.append(continuation)
                }
            }
            return
        }

        // The noncreator cannot progress until the original creator reaches
        // this point, so later creator calls belong to replacement flights and
        // must not be blocked.
        guard !isFirstCreatorBlocked else { return }
        isFirstCreatorBlocked = true

        let observedWaiters = firstCreatorWaiters
        firstCreatorWaiters.removeAll()
        observedWaiters.forEach { $0.resume() }

        let finalizationWaiters = noncreatorFinalizationWaiters
        noncreatorFinalizationWaiters.removeAll()
        finalizationWaiters.forEach { $0.resume() }

        await withCheckedContinuation { continuation in
            firstCreatorReleaseWaiters.append(continuation)
        }
    }

    func willDrainSessionFlightForDeletion() {
        deletionDrainStarted = true
        let waiters = deletionDrainWaiters
        deletionDrainWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilJoined() async {
        guard !hasJoined else { return }
        await withCheckedContinuation { continuation in
            joinWaiters.append(continuation)
        }
    }

    func waitUntilFirstCreatorIsBlocked() async {
        guard !isFirstCreatorBlocked else { return }
        await withCheckedContinuation { continuation in
            firstCreatorWaiters.append(continuation)
        }
    }

    func releaseFirstCreator() {
        let waiters = firstCreatorReleaseWaiters
        firstCreatorReleaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilDeletionDrain() async {
        guard !deletionDrainStarted else { return }
        await withCheckedContinuation { continuation in
            deletionDrainWaiters.append(continuation)
        }
    }
}
