import CryptoKit
import DeviceCheck
import Foundation

protocol AppAttestServicing: Sendable {
    var isSupported: Bool { get async }
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

/// A stateless wrapper keeps the non-Sendable DeviceCheck singleton out of the
/// authorization actor's stored state. Apple's async methods are themselves
/// imported with Sendable completion handlers.
struct SystemAppAttestService: AppAttestServicing {
    var isSupported: Bool {
        get async { DCAppAttestService.shared.isSupported }
    }

    func generateKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.generateAssertion(
            keyID,
            clientDataHash: clientDataHash
        )
    }
}

struct AppAttestCredential: Codable, Equatable, Sendable {
    struct PendingEnrollment: Codable, Equatable, Sendable {
        let challengeID: String
        let challenge: String
        let expiresAt: String
        var attestationObject: String?
    }

    let keyID: String
    var isRegistered: Bool
    var pendingEnrollment: PendingEnrollment?
}

protocol AppAttestCredentialStoring: Sendable {
    func load() async throws -> AppAttestCredential?
    func save(_ credential: AppAttestCredential) async throws
    func remove() async throws
}

/// The key identifier is the only handle Apple gives the app for the private
/// Secure Enclave key. Pending enrollment data is retained as well so a lost
/// HTTP response can retry the same single-use challenge instead of creating
/// unnecessary keys. After-first-unlock accessibility supports background sync.
actor KeychainAppAttestCredentialStore: AppAttestCredentialStoring {
    private static let account = "credential"
    private let storage: TokenStorage

    init(
        storage: TokenStorage = TokenStorage(
            service: "wardrobe.backend.app-attest",
            accessibility: .afterFirstUnlockThisDeviceOnly
        )
    ) {
        self.storage = storage
    }

    func load() throws -> AppAttestCredential? {
        let storedValue: String?
        do {
            storedValue = try storage.get(Self.account)
        } catch TokenStorageError.unexpectedData {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
        guard let value = storedValue,
              let data = value.data(using: .utf8) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(AppAttestCredential.self, from: data)
        } catch {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
    }

    func save(_ credential: AppAttestCredential) throws {
        let data = try JSONEncoder().encode(credential)
        guard let value = String(data: data, encoding: .utf8) else {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
        try storage.set(value, for: Self.account)
    }

    func remove() throws {
        try storage.remove(Self.account)
    }
}

enum AppAttestAuthorizationError: Error, Equatable, Sendable {
    case unsupportedDevice
    case invalidChallenge
    case invalidCredentialStorage
    case invalidResponse
    case network(URLError.Code)
    case serviceUnavailable
    case http(status: Int, code: String?)
    case decoding(String)
}

extension AppAttestAuthorizationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            "Secure AI requires a supported physical iPhone. Your local wardrobe and Demo Mode still work on this device."
        case .network(.notConnectedToInternet),
             .network(.networkConnectionLost),
             .network(.dataNotAllowed):
            "You appear to be offline. Reconnect to use secure AI features. Your local wardrobe remains available."
        case .network(.timedOut):
            "Secure verification took too long. Check your connection and try again."
        case .http(status: 429, code: _):
            "Secure verification is receiving too many requests. Please wait a moment and try again."
        case .serviceUnavailable, .http(status: 500...599, code: _):
            "Secure verification is temporarily unavailable. Your local wardrobe is safe on this device. Please try again."
        default:
            "Wardrobe couldn’t securely verify this installation. Your local wardrobe is safe on this device. Please try again."
        }
    }
}

/// Exchanges an Apple-certified, per-installation key for short-lived backend
/// sessions. The access token is memory-only; after relaunch or expiry, the app
/// signs a fresh one-time server challenge with the attested Secure Enclave key.
///
/// This actor is deliberately the one shared refresh point for styling, manual
/// receipt import, and background receipt import. Its in-flight task prevents
/// concurrent requests from enrolling or advancing the App Attest counter twice.
actor AppAttestAuthorization: BackendAuthorizing {
    static let shared = AppAttestAuthorization()

    private struct AccessSession: Sendable {
        let token: String
        let expiresAt: Date
    }

    private enum Purpose: String, Encodable {
        case attestation
        case assertion
    }

    private struct ChallengeRequest: Encodable {
        let purpose: Purpose
        let keyID: String?
    }

    private struct ChallengeResponse: Decodable {
        let challengeID: String
        let challenge: String
        let expiresAt: String

        private enum CodingKeys: String, CodingKey {
            case challengeID = "challenge_id"
            case challenge
            case expiresAt = "expires_at"
        }
    }

    private struct RegistrationRequest: Encodable {
        let challengeID: String
        let keyID: String
        let attestationObject: String
    }

    private struct AssertionClientData: Encodable {
        let challenge: String
        let challengeID: String
        let keyID: String
        let purpose: String
        let version: Int

        private enum CodingKeys: String, CodingKey {
            case challenge
            case challengeID = "challenge_id"
            case keyID = "key_id"
            case purpose
            case version
        }
    }

    private struct AssertionSessionRequest: Encodable {
        let challengeID: String
        let keyID: String
        let assertionObject: String
        let clientData: String
    }

    private struct SessionResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let expiresAt: String
        let installationID: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case expiresAt = "expires_at"
            case installationID = "installation_id"
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let code: String?
        }

        let detail: Detail?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Existing endpoints sometimes return a string detail. It carries
            // no machine-readable code, but must not make error parsing fail.
            detail = try? container.decode(Detail.self, forKey: .detail)
        }

        private enum CodingKeys: String, CodingKey {
            case detail
        }
    }

    private let configuredBaseURL: URL?
    private let session: URLSession
    private let service: any AppAttestServicing
    private let credentialStore: any AppAttestCredentialStoring
    private let now: @Sendable () -> Date
    private var cachedSession: AccessSession?
    private var sessionTask: Task<AccessSession, Error>?

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        service: any AppAttestServicing = SystemAppAttestService(),
        credentialStore: any AppAttestCredentialStoring = KeychainAppAttestCredentialStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        configuredBaseURL = baseURL
        self.session = session
        self.service = service
        self.credentialStore = credentialStore
        self.now = now
    }

    func accessToken(rejecting rejectedToken: String?) async throws -> String {
        if let cachedSession,
           cachedSession.token != rejectedToken,
           cachedSession.expiresAt.timeIntervalSince(now()) > 30 {
            return cachedSession.token
        }

        if cachedSession?.token == rejectedToken
            || (cachedSession?.expiresAt.timeIntervalSince(now()) ?? 0) <= 30 {
            cachedSession = nil
        }

        if let sessionTask {
            return try await sessionTask.value.token
        }

        let task = Task { try await establishSession() }
        sessionTask = task
        do {
            let established = try await task.value
            cachedSession = established
            sessionTask = nil
            return established.token
        } catch {
            sessionTask = nil
            throw error
        }
    }

    private func establishSession() async throws -> AccessSession {
        guard await service.isSupported else {
            throw AppAttestAuthorizationError.unsupportedDevice
        }

        let loadedCredential: AppAttestCredential?
        do {
            loadedCredential = try await credentialStore.load()
        } catch AppAttestAuthorizationError.invalidCredentialStorage {
            // A malformed serialized credential cannot be repaired in place.
            // Remove it and enroll cleanly now, rather than leaking a decoder
            // diagnostic or leaving every future authorization attempt stuck.
            try await removeCredential()
            loadedCredential = nil
        } catch {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
        var storedCredential = loadedCredential
        if let credential = storedCredential,
           !Self.isStructurallyValid(credential) {
            // Keychain can outlive an app installation and may also contain a
            // partial value from an older build. Never let malformed pending
            // state permanently trap authorization retries.
            try await removeCredential()
            storedCredential = nil
        }

        if let credential = storedCredential {
            if credential.isRegistered {
                do {
                    return try await assertSession(with: credential.keyID)
                } catch {
                    guard Self.requiresReenrollment(after: error) else { throw error }
                    try await removeCredential()
                }
            } else {
                do {
                    return try await enroll(credential)
                } catch {
                    if Self.isTerminalEnrollmentFailure(error) {
                        try? await removeCredential()
                    }
                    throw error
                }
            }
        }

        return try await enroll(nil)
    }

    private func enroll(_ existing: AppAttestCredential?) async throws -> AccessSession {
        var credential: AppAttestCredential
        if let existing {
            credential = existing
        } else {
            let keyID: String
            do {
                keyID = try await service.generateKey()
            } catch {
                throw AppAttestAuthorizationError.serviceUnavailable
            }
            guard Self.isCanonicalKeyID(keyID) else {
                throw AppAttestAuthorizationError.invalidResponse
            }
            credential = AppAttestCredential(
                keyID: keyID,
                isRegistered: false,
                pendingEnrollment: nil
            )
            try await saveCredential(credential)
        }

        if credential.pendingEnrollment == nil {
            let challenge: ChallengeResponse = try await post(
                path: "auth/app-attest/challenge",
                body: ChallengeRequest(purpose: .attestation, keyID: nil)
            )
            guard Self.decodeChallenge(challenge.challenge) != nil else {
                throw AppAttestAuthorizationError.invalidChallenge
            }
            credential.pendingEnrollment = .init(
                challengeID: challenge.challengeID,
                challenge: challenge.challenge,
                expiresAt: challenge.expiresAt,
                attestationObject: nil
            )
            try await saveCredential(credential)
        }

        guard var pending = credential.pendingEnrollment,
              let challengeData = Self.decodeChallenge(pending.challenge) else {
            throw AppAttestAuthorizationError.invalidChallenge
        }

        if pending.attestationObject == nil {
            let attestation: Data
            do {
                attestation = try await service.attestKey(
                    credential.keyID,
                    clientDataHash: Data(SHA256.hash(data: challengeData))
                )
            } catch {
                // Apple explicitly requires retrying serverUnavailable with the
                // same key and hash. Every other DeviceCheck failure discards
                // the identifier so the next user attempt starts cleanly.
                if !Self.isAppAttestServerUnavailable(error) {
                    try? await removeCredential()
                } else {
                    throw AppAttestAuthorizationError.serviceUnavailable
                }
                throw AppAttestAuthorizationError.serviceUnavailable
            }
            pending.attestationObject = attestation.base64EncodedString()
            credential.pendingEnrollment = pending
            try await saveCredential(credential)
        }

        guard let attestationObject = pending.attestationObject else {
            throw AppAttestAuthorizationError.invalidResponse
        }
        let response: SessionResponse
        do {
            response = try await post(
                path: "auth/app-attest/register",
                body: RegistrationRequest(
                    challengeID: pending.challengeID,
                    keyID: credential.keyID,
                    attestationObject: attestationObject
                )
            )
        } catch AppAttestAuthorizationError.http(
            status: 409,
            code: "app_attest_key_already_registered"
        ) {
            // The server may have committed registration even if its response
            // never reached the app. Never discard that valid Secure Enclave
            // key and never ask a register replay to mint a fresh session.
            // Mark it locally, then prove private-key possession with a new
            // assertion challenge before accepting any bearer.
            credential.isRegistered = true
            credential.pendingEnrollment = nil
            try await saveCredential(credential)
            return try await assertSession(with: credential.keyID)
        }
        try Self.validate(response)
        credential.isRegistered = true
        credential.pendingEnrollment = nil
        try await saveCredential(credential)
        return makeAccessSession(response)
    }

    private func assertSession(with keyID: String) async throws -> AccessSession {
        let challenge: ChallengeResponse = try await post(
            path: "auth/app-attest/challenge",
            body: ChallengeRequest(purpose: .assertion, keyID: keyID)
        )
        guard Self.decodeChallenge(challenge.challenge) != nil else {
            throw AppAttestAuthorizationError.invalidChallenge
        }

        let clientData = AssertionClientData(
            challenge: challenge.challenge,
            challengeID: challenge.challengeID,
            keyID: keyID,
            purpose: Purpose.assertion.rawValue,
            version: 1
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encodedClientData = try encoder.encode(clientData)
        let assertion: Data
        do {
            assertion = try await service.generateAssertion(
                keyID,
                clientDataHash: Data(SHA256.hash(data: encodedClientData))
            )
        } catch {
            if Self.isAppAttestInvalidKey(error) { throw error }
            throw AppAttestAuthorizationError.serviceUnavailable
        }
        let response: SessionResponse = try await post(
            path: "auth/app-attest/session",
            body: AssertionSessionRequest(
                challengeID: challenge.challengeID,
                keyID: keyID,
                assertionObject: assertion.base64EncodedString(),
                clientData: encodedClientData.base64EncodedString()
            )
        )
        try Self.validate(response)
        return makeAccessSession(response)
    }

    private func makeAccessSession(_ response: SessionResponse) -> AccessSession {
        AccessSession(
            token: response.accessToken,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    private func baseURL() throws -> URL {
        if let configuredBaseURL { return configuredBaseURL }
        return try BackendConfig.load()
    }

    private func saveCredential(_ credential: AppAttestCredential) async throws {
        do {
            try await credentialStore.save(credential)
        } catch let error as AppAttestAuthorizationError {
            throw error
        } catch {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
    }

    private func removeCredential() async throws {
        do {
            try await credentialStore.remove()
        } catch {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: try baseURL().appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw AppAttestAuthorizationError.network(urlError.code)
        }
        guard let response = urlResponse as? HTTPURLResponse else {
            throw AppAttestAuthorizationError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AppAttestAuthorizationError.http(
                status: response.statusCode,
                code: envelope?.detail?.code
            )
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AppAttestAuthorizationError.decoding(String(describing: error))
        }
    }

    private static func validate(_ response: SessionResponse) throws {
        guard !response.accessToken.isEmpty,
              response.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
              response.expiresIn > 30,
              !response.expiresAt.isEmpty,
              !response.installationID.isEmpty else {
            throw AppAttestAuthorizationError.invalidResponse
        }
    }

    private static func decodeChallenge(_ value: String) -> Data? {
        var standard = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standard.count % 4
        if remainder != 0 {
            standard.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: standard), data.count == 32 else { return nil }
        return data
    }

    private static func isCanonicalKeyID(_ value: String) -> Bool {
        guard let decoded = Data(base64Encoded: value), decoded.count == 32 else {
            return false
        }
        return decoded.base64EncodedString() == value
    }

    private static func isStructurallyValid(_ credential: AppAttestCredential) -> Bool {
        guard isCanonicalKeyID(credential.keyID) else { return false }
        if credential.isRegistered {
            return credential.pendingEnrollment == nil
        }
        guard let pending = credential.pendingEnrollment else { return true }
        guard !pending.challengeID.isEmpty,
              !pending.expiresAt.isEmpty,
              decodeChallenge(pending.challenge) != nil else {
            return false
        }
        guard let attestationObject = pending.attestationObject else { return true }
        guard !attestationObject.isEmpty,
              let decoded = Data(base64Encoded: attestationObject) else {
            return false
        }
        return decoded.base64EncodedString() == attestationObject
    }

    private static func requiresReenrollment(after error: Error) -> Bool {
        if isAppAttestInvalidKey(error) { return true }
        guard case let AppAttestAuthorizationError.http(_, code) = error else { return false }
        return code == "unknown_app_attest_key" || code == "revoked_app_attest_key"
    }

    private static func isTerminalEnrollmentFailure(_ error: Error) -> Bool {
        guard case let AppAttestAuthorizationError.http(status, _) = error else { return false }
        return (400..<500).contains(status) && status != 429
    }

    private static func isAppAttestInvalidKey(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == DCError.errorDomain
            && nsError.code == DCError.Code.invalidKey.rawValue
    }

    private static func isAppAttestServerUnavailable(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == DCError.errorDomain
            && nsError.code == DCError.Code.serverUnavailable.rawValue
    }
}
