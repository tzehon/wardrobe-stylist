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

/// Internal concurrency seam used to deterministically exercise actor
/// reentrancy. Production has no observer and pays no suspension cost.
protocol AppAttestSessionFlightObserving: Sendable {
    func didJoinSessionFlight() async
    func willFinalizeSessionFlight(createdByCaller: Bool) async
    func willDrainSessionFlightForDeletion() async
}

extension AppAttestSessionFlightObserving {
    func willDrainSessionFlightForDeletion() async {}
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
    case deletionInProgress
    case deletionConfirmationPending
    case retiredSession
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
        case .deletionInProgress:
            "Server security data is already being deleted. Please wait for it to finish."
        case .deletionConfirmationPending:
            "Server deletion still needs confirmation. Open Privacy & Data in Settings and retry Delete Server Security Data."
        case .retiredSession:
            "This AI request stopped because its anonymous server identity was deleted. Try the action again to create a new identity."
        default:
            "Wardrobe couldn’t securely verify this installation. Your local wardrobe is safe on this device. Please try again."
        }
    }
}

enum ServerIdentityDeletionResult: Equatable, Sendable {
    case deleted
    case alreadyAbsent
    case noVerifiableIdentity
}

protocol ServerIdentityDeleting: Sendable {
    func deleteServerIdentity() async throws -> ServerIdentityDeletionResult
}

/// Exchanges an Apple-certified, per-installation key for short-lived backend
/// sessions. The access token is memory-only; after relaunch or expiry, the app
/// signs a fresh one-time server challenge with the attested Secure Enclave key.
///
/// This actor is deliberately the one shared refresh point for styling, manual
/// receipt import, and background receipt import. Its in-flight task prevents
/// concurrent requests from enrolling or advancing the App Attest counter twice.
actor AppAttestAuthorization: BackendAuthorizing, ServerIdentityDeleting {
    static let shared = AppAttestAuthorization()

    private struct AccessSession: Sendable {
        let token: String
        let expiresAt: Date
    }

    private struct SessionFlight: Sendable {
        let id: UUID
        let task: Task<AccessSession, Error>
    }

    private enum Purpose: String, Encodable {
        case attestation
        case assertion
        case deletion
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

    private struct InstallationDeletionRequest: Encodable {
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
    private let sessionFlightObserver: (any AppAttestSessionFlightObserving)?
    private var cachedSession: AccessSession?
    private var sessionFlight: SessionFlight?
    // Keep only one-way digests for historical bearers. They live only for the
    // current process: app termination also ends every in-flight caller that
    // could present one. This fences a pre-deletion request even if iOS
    // suspends its Task after receiving a 401 for an arbitrary duration.
    private var returnedSessionDigests: Set<Data> = []
    private var retiredSessionDigests: Set<Data> = []
    private var identityGeneration: UInt64 = 0
    private var deletionInProgress = false
    // Once a signed deletion proof has been dispatched, a timeout or 503 can
    // mean the logical DELETE committed but its maintenance confirmation was
    // lost. Keep the credential for an idempotent retry, while blocking every
    // new AI session until the server confirms absence.
    private var deletionPendingConfirmation = false

    init(
        baseURL: URL? = nil,
        session: URLSession = BackendHTTPSession.shared,
        service: any AppAttestServicing = SystemAppAttestService(),
        credentialStore: any AppAttestCredentialStoring = KeychainAppAttestCredentialStore(),
        now: @escaping @Sendable () -> Date = Date.init,
        sessionFlightObserver: (any AppAttestSessionFlightObserving)? = nil
    ) {
        configuredBaseURL = baseURL
        self.session = session
        self.service = service
        self.credentialStore = credentialStore
        self.now = now
        self.sessionFlightObserver = sessionFlightObserver
    }

    func accessToken(rejecting rejectedToken: String?) async throws -> String {
        let startingIdentityGeneration = identityGeneration
        var rejectedReplacementAttempts = 0
        while true {
            guard startingIdentityGeneration == identityGeneration else {
                throw AppAttestAuthorizationError.retiredSession
            }
            if let rejectedToken,
               retiredSessionDigests.contains(Self.tokenDigest(rejectedToken)) {
                throw AppAttestAuthorizationError.retiredSession
            }
            guard !deletionInProgress else {
                throw AppAttestAuthorizationError.deletionInProgress
            }
            guard !deletionPendingConfirmation else {
                throw AppAttestAuthorizationError.deletionConfirmationPending
            }
            if let cachedSession,
               cachedSession.token != rejectedToken,
               cachedSession.expiresAt.timeIntervalSince(now()) > 30 {
                return publish(cachedSession)
            }

            if cachedSession?.token == rejectedToken
                || (cachedSession?.expiresAt.timeIntervalSince(now()) ?? 0) <= 30 {
                cachedSession = nil
            }

            let flight: SessionFlight
            let createdByCaller: Bool
            if let existing = sessionFlight {
                flight = existing
                createdByCaller = false
                await sessionFlightObserver?.didJoinSessionFlight()
            } else {
                let made = SessionFlight(
                    id: UUID(),
                    task: Task { try await establishSession() }
                )
                sessionFlight = made
                flight = made
                createdByCaller = true
            }

            let established: AccessSession
            do {
                established = try await flight.task.value
            } catch {
                // A late waiter must never erase a newer flight that another
                // caller started after observing this one's failure.
                if sessionFlight?.id == flight.id {
                    sessionFlight = nil
                }
                throw error
            }

            // A deletion that began while this caller awaited its shared
            // assertion owns the credential boundary now. Do not publish or
            // return the just-created bearer; the deletion path first drains
            // this flight, then proves against the resulting latest counter.
            guard !deletionInProgress else {
                if sessionFlight?.id == flight.id {
                    sessionFlight = nil
                }
                throw AppAttestAuthorizationError.deletionInProgress
            }

            await sessionFlightObserver?.willFinalizeSessionFlight(
                createdByCaller: createdByCaller
            )
            guard startingIdentityGeneration == identityGeneration else {
                throw AppAttestAuthorizationError.retiredSession
            }
            guard !deletionInProgress else {
                throw AppAttestAuthorizationError.deletionInProgress
            }

            // Every waiter may be first to resume. Finalize only the generation
            // it actually awaited, so an old completion cannot overwrite a
            // replacement refresh that is already in flight.
            if sessionFlight?.id == flight.id {
                cachedSession = established
                sessionFlight = nil
            }

            if established.token == rejectedToken {
                guard rejectedReplacementAttempts == 0 else {
                    if cachedSession?.token == rejectedToken {
                        cachedSession = nil
                    }
                    throw AppAttestAuthorizationError.invalidResponse
                }
                rejectedReplacementAttempts += 1
                if cachedSession?.token == rejectedToken {
                    cachedSession = nil
                }
                // The completed flight produced the exact bearer the backend
                // rejected. Join or create the next generation instead of
                // spending the one allowed API retry on the same credential.
                continue
            }

            if cachedSession?.token == established.token {
                return publish(established)
            }
            // Another caller invalidated or superseded this completion while
            // the actor was reentrant. Re-evaluate the current cache/flight.
        }
    }

    func deleteServerIdentity() async throws -> ServerIdentityDeletionResult {
        guard !deletionInProgress else {
            throw AppAttestAuthorizationError.deletionInProgress
        }
        deletionInProgress = true
        defer { deletionInProgress = false }

        await drainSessionFlightBeforeDeletion()

        guard await service.isSupported else {
            throw AppAttestAuthorizationError.unsupportedDevice
        }

        let credential: AppAttestCredential?
        do {
            credential = try await credentialStore.load()
        } catch AppAttestAuthorizationError.invalidCredentialStorage {
            try await finishLocalServerIdentityDeletion()
            return .noVerifiableIdentity
        } catch let error as AppAttestAuthorizationError {
            throw error
        } catch {
            throw AppAttestAuthorizationError.invalidCredentialStorage
        }
        guard let credential else {
            // A missing Keychain credential means this installation can no
            // longer prove control of the server identity. Do not leave a
            // memory-only bearer usable after reporting that state.
            retireReturnedSessionsAndClearMemory()
            deletionPendingConfirmation = false
            return .noVerifiableIdentity
        }
        guard Self.isStructurallyValid(credential) else {
            try await finishLocalServerIdentityDeletion()
            return .noVerifiableIdentity
        }

        let challenge: ChallengeResponse
        do {
            challenge = try await post(
                path: "auth/app-attest/challenge",
                body: ChallengeRequest(purpose: .deletion, keyID: credential.keyID)
            )
        } catch AppAttestAuthorizationError.http(
            status: 401,
            code: "unknown_app_attest_key"
        ) {
            try await finishLocalServerIdentityDeletion()
            return .alreadyAbsent
        }
        guard Self.decodeChallenge(challenge.challenge) != nil else {
            throw AppAttestAuthorizationError.invalidChallenge
        }

        let proof: (assertion: Data, clientData: Data)
        do {
            proof = try await makeAssertion(
                challenge: challenge,
                keyID: credential.keyID,
                purpose: .deletion
            )
        } catch {
            guard Self.isAppAttestInvalidKey(error) else { throw error }
            // Apple can no longer produce possession proof for this key. The
            // inaccessible server row therefore falls back to inactivity
            // expiry, while this process must stop publishing its sessions.
            try await finishLocalServerIdentityDeletion()
            return .noVerifiableIdentity
        }
        // Dispatching the possession proof is the point of no return: any
        // response failure is ambiguous. Fence existing bearers before the
        // request leaves this actor, retain the key for a safe retry, and do
        // not permit re-enrollment until absence is confirmed.
        deletionPendingConfirmation = true
        retireReturnedSessionsAndClearMemory()
        do {
            try await postWithoutResponse(
                path: "auth/app-attest/delete",
                body: InstallationDeletionRequest(
                    challengeID: challenge.challengeID,
                    keyID: credential.keyID,
                    assertionObject: proof.assertion.base64EncodedString(),
                    clientData: proof.clientData.base64EncodedString()
                )
            )
        } catch AppAttestAuthorizationError.http(
            status: 401,
            code: "unknown_app_attest_key"
        ) {
            // Retention cleanup or another proven deletion can win after this
            // client receives its challenge. The server row is definitively
            // absent, so apply the same local credential fence as the
            // idempotent challenge response.
            try await finishLocalServerIdentityDeletion()
            return .alreadyAbsent
        }
        try await finishLocalServerIdentityDeletion()
        return .deleted
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
                    // Deletion must prove possession of the identity that was
                    // present when the user confirmed. A failing refresh may
                    // normally replace a stale key, but it must not swap key A
                    // for key B while deletion is draining this flight.
                    guard !deletionInProgress else {
                        throw AppAttestAuthorizationError.deletionInProgress
                    }
                    try await removeCredential()
                    // Keychain mutation is an actor-reentrancy boundary. If
                    // deletion began during it, report that the original key
                    // can no longer be proven instead of enrolling a new one.
                    guard !deletionInProgress else {
                        throw AppAttestAuthorizationError.deletionInProgress
                    }
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

        guard !deletionInProgress else {
            throw AppAttestAuthorizationError.deletionInProgress
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
        credential.isRegistered = true
        credential.pendingEnrollment = nil
        try await saveCredential(credential)
        return try makeAccessSession(response)
    }

    private func assertSession(with keyID: String) async throws -> AccessSession {
        let challenge: ChallengeResponse = try await post(
            path: "auth/app-attest/challenge",
            body: ChallengeRequest(purpose: .assertion, keyID: keyID)
        )
        guard Self.decodeChallenge(challenge.challenge) != nil else {
            throw AppAttestAuthorizationError.invalidChallenge
        }

        let proof = try await makeAssertion(
            challenge: challenge,
            keyID: keyID,
            purpose: .assertion
        )
        let response: SessionResponse = try await post(
            path: "auth/app-attest/session",
            body: AssertionSessionRequest(
                challengeID: challenge.challengeID,
                keyID: keyID,
                assertionObject: proof.assertion.base64EncodedString(),
                clientData: proof.clientData.base64EncodedString()
            )
        )
        return try makeAccessSession(response)
    }

    private func makeAssertion(
        challenge: ChallengeResponse,
        keyID: String,
        purpose: Purpose
    ) async throws -> (assertion: Data, clientData: Data) {
        let clientData = AssertionClientData(
            challenge: challenge.challenge,
            challengeID: challenge.challengeID,
            keyID: keyID,
            purpose: purpose.rawValue,
            version: 1
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encodedClientData = try encoder.encode(clientData)
        do {
            let assertion = try await service.generateAssertion(
                keyID,
                clientDataHash: Data(SHA256.hash(data: encodedClientData))
            )
            return (assertion, encodedClientData)
        } catch {
            if Self.isAppAttestInvalidKey(error) { throw error }
            throw AppAttestAuthorizationError.serviceUnavailable
        }
    }

    private func makeAccessSession(_ response: SessionResponse) throws -> AccessSession {
        let referenceDate = now()
        guard Self.isCanonicalSessionToken(response.accessToken),
              response.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
              (60...900).contains(response.expiresIn),
              let absoluteExpiration = Self.parseUTCDate(response.expiresAt),
              UUID(uuidString: response.installationID) != nil else {
            throw AppAttestAuthorizationError.invalidResponse
        }

        let relativeExpiration = referenceDate.addingTimeInterval(
            TimeInterval(response.expiresIn)
        )
        let effectiveExpiration = min(relativeExpiration, absoluteExpiration)
        guard effectiveExpiration.timeIntervalSince(referenceDate) > 30 else {
            throw AppAttestAuthorizationError.invalidResponse
        }
        return AccessSession(token: response.accessToken, expiresAt: effectiveExpiration)
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

    private func finishLocalServerIdentityDeletion() async throws {
        // The server identity is definitively absent (or the private key is
        // permanently unusable). Fence every bearer before touching Keychain:
        // local cleanup failure must never make an old session publishable.
        retireReturnedSessionsAndClearMemory()
        try await removeCredential()
        deletionPendingConfirmation = false
    }

    private func publish(_ session: AccessSession) -> String {
        returnedSessionDigests.insert(Self.tokenDigest(session.token))
        return session.token
    }

    private func retireReturnedSessionsAndClearMemory() {
        retiredSessionDigests.formUnion(returnedSessionDigests)
        returnedSessionDigests.removeAll()
        cachedSession = nil
        sessionFlight = nil
        identityGeneration &+= 1
    }

    private static func tokenDigest(_ token: String) -> Data {
        Data(SHA256.hash(data: Data(token.utf8)))
    }

    private func drainSessionFlightBeforeDeletion() async {
        guard let flight = sessionFlight else { return }
        await sessionFlightObserver?.willDrainSessionFlightForDeletion()
        _ = await flight.task.result
        if sessionFlight?.id == flight.id {
            sessionFlight = nil
        }
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let (data, _) = try await performPost(path: path, body: body)

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AppAttestAuthorizationError.decoding(String(describing: error))
        }
    }

    private func postWithoutResponse<Body: Encodable>(
        path: String,
        body: Body
    ) async throws {
        let (data, response) = try await performPost(path: path, body: body)
        guard response.statusCode == 204, data.isEmpty else {
            throw AppAttestAuthorizationError.invalidResponse
        }
    }

    private func performPost<Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> (Data, HTTPURLResponse) {
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
        return (data, response)
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

    private static func isCanonicalSessionToken(_ value: String) -> Bool {
        guard value.utf8.count == 43,
              !value.contains("="),
              value.unicodeScalars.allSatisfy({ scalar in
                  scalar.isASCII
                      && (CharacterSet.alphanumerics.contains(scalar)
                          || scalar == "-" || scalar == "_")
              }) else {
            return false
        }
        guard let decoded = decodeBase64URL(value), decoded.count == 32 else {
            return false
        }
        return encodeBase64URL(decoded) == value
    }

    private static func parseUTCDate(_ value: String) -> Date? {
        guard value.hasSuffix("Z") || value.hasSuffix("+00:00") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var standard = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standard.count % 4
        if remainder != 0 {
            standard.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: standard)
    }

    private static func encodeBase64URL(_ value: Data) -> String {
        value.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
