import Foundation

/// Sends `/extract` requests to the Wardrobe backend over HTTP.
///
/// Stateless. Single seam over `URLSession` so tests can swap a stub session
/// (see `URLProtocolStub` in WardrobeTests). Bearer auth with the device token.
/// Snake-case ↔ camelCase conversion runs through `JSONEncoder` /
/// `JSONDecoder` strategies so the Swift models can stay idiomatic.
struct ExtractClient: Sendable {
    let baseURL: URL
    let deviceToken: String
    let session: URLSession

    init(baseURL: URL, deviceToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.deviceToken = deviceToken
        self.session = session
    }

    func extract(_ payload: ExtractRequest) async throws -> ExtractResponse {
        var request = URLRequest(url: baseURL.appending(path: "extract"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ExtractError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ExtractError.http(status: http.statusCode, body: data)
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ExtractResponse.self, from: data)
        } catch {
            throw ExtractError.decoding(String(describing: error))
        }
    }
}
