import Foundation

/// Sends `/recommend` requests to the Wardrobe backend over HTTP (Phase 5).
///
/// Stateless. Single seam over `URLSession` so tests can swap a stub session
/// (see `URLProtocolStub` in WardrobeTests). Each call gets a short-lived bearer
/// from the per-installation App Attest authorization actor.
/// Snake-case ↔ camelCase conversion runs through `JSONEncoder` / `JSONDecoder`
/// strategies so the Swift models can stay idiomatic. Mirrors `ExtractClient`.
struct RecommendClient: Sendable {
    let baseURL: URL
    let authorization: any BackendAuthorizing
    let session: URLSession

    init(
        baseURL: URL,
        authorization: any BackendAuthorizing = AppAttestAuthorization.shared,
        session: URLSession = BackendHTTPSession.shared
    ) {
        self.baseURL = baseURL
        self.authorization = authorization
        self.session = session
    }

    func recommend(_ payload: RecommendRequest) async throws -> RecommendResponse {
        var rejectedToken: String?
        for attempt in 0..<2 {
            let token = try await authorization.accessToken(rejecting: rejectedToken)
            try Task.checkCancellation()
            let result = try await send(payload, token: token)
            if case let .failure(status, _) = result, status == 401, attempt == 0 {
                rejectedToken = token
                continue
            }
            return try decode(result)
        }
        throw RecommendError.invalidResponse
    }

    private enum Result {
        case success(Data)
        case failure(status: Int, body: Data)
    }

    private func send(_ payload: RecommendRequest, token: String) async throws -> Result {
        var request = URLRequest(url: baseURL.appending(path: "recommend"))
        request.httpMethod = "POST"
        // A recommendation must always reach a terminal UI state. A bounded
        // request avoids leaving Today on an indefinite spinner when a mobile
        // connection stalls without immediately failing.
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecommendError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            return .failure(status: http.statusCode, body: data)
        }
        return .success(data)
    }

    private func decode(_ result: Result) throws -> RecommendResponse {
        guard case let .success(data) = result else {
            if case let .failure(status, body) = result {
                throw RecommendError.http(status: status, body: body)
            }
            throw RecommendError.invalidResponse
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(RecommendResponse.self, from: data)
        } catch {
            throw RecommendError.decoding(String(describing: error))
        }
    }
}
