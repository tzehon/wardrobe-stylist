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
        installAuthHandler(challenges: [challenge], tokens: ["session-one"])
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let first = try await authorization.accessToken(rejecting: nil)
        let second = try await authorization.accessToken(rejecting: nil)

        #expect(first == "session-one")
        #expect(second == "session-one")
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
        installAuthHandler(challenges: [challenge], tokens: ["asserted-session"])
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "asserted-session")
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
        installAuthHandler(
            challenges: [Data(repeating: 0x2d, count: 32)],
            tokens: ["shared-session"]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        async let first = authorization.accessToken(rejecting: nil)
        async let second = authorization.accessToken(rejecting: nil)
        let (firstToken, secondToken) = try await (first, second)

        #expect(firstToken == "shared-session")
        #expect(secondToken == "shared-session")
        #expect(URLProtocolStub.captured.map(\.url?.path) == [
            "/auth/app-attest/challenge",
            "/auth/app-attest/session",
        ])
        #expect(await service.assertionHashes.count == 1)
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
        installAuthHandler(
            challenges: [oldChallenge, newChallenge],
            tokens: ["replacement-session"]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "replacement-session")
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
        installAuthHandler(
            challenges: [Data(repeating: 0x5d, count: 32)],
            tokens: ["replacement-session"]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "replacement-session")
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
        installAuthHandler(
            challenges: [Data(repeating: 0x6d, count: 32)],
            tokens: ["recovered-session"]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "recovered-session")
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
        installAuthHandler(
            challenges: [Data(repeating: 0x6e, count: 32)],
            tokens: ["recovered-session"]
        )
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "recovered-session")
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
                    Data(#"{"access_token":"proof-session","token_type":"Bearer","expires_in":900,"expires_at":"2027-01-15T08:15:00Z","installation_id":"10000000-0000-0000-0000-000000000001"}"#.utf8)
                )
            default:
                Issue.record("Unexpected path")
                return (Self.response(500, request: request), nil)
            }
        }
        defer { URLProtocolStub.reset() }

        let authorization = makeAuthorization(service: service, store: store)
        let token = try await authorization.accessToken(rejecting: nil)

        #expect(token == "proof-session")
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
        store: FakeAppAttestCredentialStore
    ) -> AppAttestAuthorization {
        AppAttestAuthorization(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            service: service,
            credentialStore: store,
            now: { now }
        )
    }

    private func installAuthHandler(challenges: [Data], tokens: [String]) {
        nonisolated(unsafe) var challengeIndex = 0
        nonisolated(unsafe) var tokenIndex = 0
        URLProtocolStub.install { request in
            let body: String
            switch request.url?.path {
            case "/auth/app-attest/challenge":
                let index = challengeIndex
                challengeIndex += 1
                body = #"{"challenge_id":"challenge-\#(index)","challenge":"\#(base64URL(challenges[index]))","expires_at":"2027-01-15T08:15:00Z"}"#
            case "/auth/app-attest/register", "/auth/app-attest/session":
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

private actor FakeAppAttestCredentialStore: AppAttestCredentialStoring {
    var credential: AppAttestCredential?
    private var loadError: AppAttestAuthorizationError?
    private(set) var removeCount = 0

    init(
        credential: AppAttestCredential? = nil,
        loadError: AppAttestAuthorizationError? = nil
    ) {
        self.credential = credential
        self.loadError = loadError
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

    func remove() {
        removeCount += 1
        credential = nil
    }
}

private actor FakeAppAttestService: AppAttestServicing {
    let supported: Bool
    let generatedKeyID: String
    let attestation: Data
    let assertion: Data
    let assertionError: (any Error)?
    let assertionDelay: Duration
    private(set) var generatedKeyCount = 0
    private(set) var attestationHashes: [Data] = []
    private(set) var assertionHashes: [Data] = []

    init(
        isSupported: Bool = true,
        generatedKeyID: String,
        attestation: Data,
        assertion: Data,
        assertionError: (any Error)? = nil,
        assertionDelay: Duration = .zero
    ) {
        supported = isSupported
        self.generatedKeyID = generatedKeyID
        self.attestation = attestation
        self.assertion = assertion
        self.assertionError = assertionError
        self.assertionDelay = assertionDelay
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
        if assertionDelay > .zero {
            try await Task.sleep(for: assertionDelay)
        }
        if let assertionError { throw assertionError }
        return assertion
    }
}
