import Foundation
import Testing

@testable import Wardrobe

struct RecommendClientTests {

    private let baseURL = URL(string: "http://test.local")!

    private func makeClient(token: String = "test-token") -> RecommendClient {
        RecommendClient(
            baseURL: baseURL,
            authorization: StaticBackendAuthorization(token: token),
            session: URLProtocolStub.makeSession()
        )
    }

    private func makeHTTPResponse(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "http://test.local/recommend")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func storedPropertyNames<T>(of value: T) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    private let successBody: String = #"""
    {
      "occasion": "relaxed weekend",
      "color_story": "soft neutrals with a tan warmth",
      "rationale": "The tee keeps the trouser easy; suede warms it up.",
      "item_ids": ["a", "b", "c"],
      "alternates": [
        {"item_ids": ["a", "b", "d"], "rationale": "Layer the jacket when it cools."}
      ],
      "usage": {
        "input_tokens": 200,
        "output_tokens": 60,
        "cache_creation_input_tokens": 20,
        "cache_read_input_tokens": 10
      }
    }
    """#

    private func sampleRequest() -> RecommendRequest {
        RecommendRequest(
            items: [
                RecommendCatalogItem(
                    id: "a",
                    name: "Oversized Tee",
                    category: "top",
                    brand: "Example Brand",
                    colors: ["white"],
                    material: "cotton"
                ),
                RecommendCatalogItem(id: "b", name: "Slim Trouser", category: "bottom", colors: ["navy"]),
                RecommendCatalogItem(id: "c", name: "Suede Loafers", category: "shoe"),
            ],
            recentlyWornIds: ["b"],
            itemPreferences: [
                RecommendItemPreference(id: "a", averageRating: 4.5, ratingCount: 2),
            ],
            occasion: "relaxed weekend"
        )
    }

    // MARK: -

    @Test func sendsBearerTokenAndSnakeCaseBodyToRecommendPath() async throws {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let request = sampleRequest()
        let sourceItem = try #require(request.items.first)
        let sourcePreference = try #require(request.itemPreferences.first)

        // Mirror includes nil optional stored properties, so a future wire-model
        // field cannot hide from this allowlist merely because the fixture leaves
        // it nil and synthesized encoding omits it.
        #expect(storedPropertyNames(of: request) == [
            "items",
            "recentlyWornIds",
            "itemPreferences",
            "occasion",
        ])
        #expect(storedPropertyNames(of: sourceItem) == [
            "id",
            "name",
            "category",
            "brand",
            "colors",
            "material",
        ])
        #expect(storedPropertyNames(of: sourcePreference) == [
            "id",
            "averageRating",
            "ratingCount",
        ])

        let client = makeClient(token: "abc-123")
        let response = try await client.recommend(request)

        #expect(response.itemIds == ["a", "b", "c"])
        #expect(response.occasion == "relaxed weekend")
        #expect(response.colorStory == "soft neutrals with a tan warmth")
        #expect(response.alternates.first?.itemIds == ["a", "b", "d"])
        #expect(response.usage == RecommendUsage(
            inputTokens: 200,
            outputTokens: 60,
            cacheCreationInputTokens: 20,
            cacheReadInputTokens: 10
        ))

        let req = try #require(URLProtocolStub.captured.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/recommend")
        #expect(req.timeoutInterval == 30)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer abc-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // Body went through `convertToSnakeCase`.
        let body = try #require(URLProtocolStub.capturedBodies.first)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(Set(json.keys) == [
            "items",
            "recently_worn_ids",
            "item_preferences",
            "occasion",
        ])
        #expect(json["recently_worn_ids"] as? [String] == ["b"])
        let preferences = try #require(json["item_preferences"] as? [[String: Any]])
        #expect(preferences.allSatisfy { Set($0.keys) == [
            "id",
            "average_rating",
            "rating_count",
        ] })
        #expect(preferences.first?["id"] as? String == "a")
        #expect(preferences.first?["average_rating"] as? Double == 4.5)
        #expect(preferences.first?["rating_count"] as? Int == 2)
        #expect(json["occasion"] as? String == "relaxed weekend")
        let items = try #require(json["items"] as? [[String: Any]])
        let firstItem = try #require(items.first)
        let allowedItemKeys: Set<String> = [
            "id",
            "name",
            "category",
            "brand",
            "colors",
            "material",
        ]
        #expect(items.allSatisfy { Set($0.keys).isSubset(of: allowedItemKeys) })
        #expect(Set(firstItem.keys) == allowedItemKeys)
        #expect(firstItem["id"] as? String == "a")
        #expect(firstItem["brand"] as? String == "Example Brand")
        #expect(firstItem["material"] as? String == "cotton")
    }

    @Test func http401IsSurfacedAsHttpError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(401), Data(#"{"detail": "Invalid bearer token."}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.recommend(sampleRequest())
            Issue.record("Expected RecommendError.http")
        } catch let RecommendError.http(status, _) {
            #expect(status == 401)
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func http401RefreshesAuthorizationAndRetriesExactlyOnce() async throws {
        let authorization = RecommendRotatingAuthorization(
            initialToken: "expired-token",
            refreshedToken: "refreshed-token"
        )
        URLProtocolStub.install { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-token" {
                return (
                    self.makeHTTPResponse(401),
                    Data(#"{"detail": "Expired bearer token."}"#.utf8)
                )
            }
            return (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = RecommendClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        let response = try await client.recommend(sampleRequest())

        #expect(response.itemIds == ["a", "b", "c"])
        #expect(URLProtocolStub.captured.map {
            $0.value(forHTTPHeaderField: "Authorization")
        } == ["Bearer expired-token", "Bearer refreshed-token"])
        let rejectedTokens = await authorization.rejectedTokens
        #expect(rejectedTokens.count == 2)
        #expect(rejectedTokens[0] == nil)
        #expect(rejectedTokens[1] == "expired-token")
    }

    @Test func late401ForADeletedIdentityDoesNotResendTheWardrobePayload() async {
        let authorization = RecommendRetiredBearerAuthorization(
            retiredToken: "deleted-identity-token"
        )
        URLProtocolStub.install { _ in
            (
                self.makeHTTPResponse(401),
                Data(#"{"detail": "Deleted anonymous identity."}"#.utf8)
            )
        }
        defer { URLProtocolStub.reset() }

        let client = RecommendClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        await #expect(throws: AppAttestAuthorizationError.retiredSession) {
            _ = try await client.recommend(sampleRequest())
        }

        #expect(URLProtocolStub.captured.count == 1)
        #expect(URLProtocolStub.capturedBodies.count == 1)
        #expect(
            URLProtocolStub.capturedBodies[0]
                .range(of: Data("Oversized Tee".utf8)) != nil
        )
        #expect(await authorization.replacementTokenCount == 0)
        #expect(await authorization.rejectedTokens == [nil, "deleted-identity-token"])
    }

    @Test func cancellationWhileAuthorizationIsSuspendedSendsNoWardrobePayload() async {
        let authorization = RecommendSuspendedAuthorization()
        URLProtocolStub.install { _ in
            Issue.record("A canceled recommendation must not send its wardrobe payload")
            return (self.makeHTTPResponse(200), Data(self.successBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = RecommendClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        let task = Task {
            try await client.recommend(sampleRequest())
        }

        await authorization.waitUntilRequested()
        task.cancel()
        await authorization.resume(with: "unused-token")

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(URLProtocolStub.capturedBodies.isEmpty)
    }

    @Test func crossOrigin307DoesNotForwardBearerOrWardrobePayload() throws {
        let response = makeHTTPResponse(307)
        var proposed = URLRequest(url: URL(string: "https://attacker.example/collect")!)
        proposed.httpMethod = "POST"
        proposed.setValue(
            "Bearer short-lived-private-token",
            forHTTPHeaderField: "Authorization"
        )
        proposed.httpBody = try JSONEncoder().encode(sampleRequest())

        #expect(BackendRedirectPolicy.redirectedRequest(
            for: response,
            proposedRequest: proposed
        ) == nil)
        #expect(proposed.value(forHTTPHeaderField: "Authorization") != nil)
        #expect(proposed.httpBody?.range(of: Data("Oversized Tee".utf8)) != nil)
    }

    @Test func http502IsSurfacedAsHttpError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(502), Data(#"{"detail": "Model returned bad input."}"#.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        await #expect(throws: RecommendError.self) {
            _ = try await client.recommend(self.sampleRequest())
        }
    }

    @Test func malformedBodyIsSurfacedAsDecodingError() async {
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data("not json".utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        do {
            _ = try await client.recommend(sampleRequest())
            Issue.record("Expected decoding error")
        } catch let RecommendError.decoding(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func emptyAlternatesDecode() async throws {
        let body = #"""
        {"occasion": "smart office", "color_story": "monochrome", "rationale": "Clean column.",
         "item_ids": ["a", "b"], "alternates": [],
         "usage": {"input_tokens": 10, "output_tokens": 5,
                   "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}
        """#
        URLProtocolStub.install { _ in
            (self.makeHTTPResponse(200), Data(body.utf8))
        }
        defer { URLProtocolStub.reset() }

        let client = makeClient()
        let response = try await client.recommend(sampleRequest())
        #expect(response.alternates.isEmpty)
        #expect(response.itemIds == ["a", "b"])
    }

    @Test func usageMustMatchTheExactNonnegativeWireContract() async {
        let invalidUsageValues = [
            #"{"input_tokens":10,"output_tokens":-1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}"#,
            #"{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":0}"#,
            #"{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"private_payload":1}"#,
        ]
        defer { URLProtocolStub.reset() }

        for usage in invalidUsageValues {
            let body = Data(
                #"{"occasion":"work","color_story":"navy","rationale":"balanced","item_ids":["a","b"],"alternates":[],"usage":\#(usage)}"#.utf8
            )
            URLProtocolStub.reset()
            URLProtocolStub.install { request in
                (self.makeHTTPResponse(200), body)
            }

            do {
                _ = try await makeClient().recommend(sampleRequest())
                Issue.record("Expected invalid usage to fail decoding")
            } catch RecommendError.decoding {
                // Expected: the response never reaches the UI/cache.
            } catch {
                Issue.record("Wrong error: \(error)")
            }
        }
    }

    @Test func requestValidationPinsEveryBackendBoundary() throws {
        let maximumItems = (0..<RecommendContractLimits.maximumItems).map { index in
            RecommendCatalogItem(
                id: String(index),
                name: String(repeating: "n", count: RecommendContractLimits.maximumNameLength),
                category: String(
                    repeating: "c",
                    count: RecommendContractLimits.maximumCategoryLength
                ),
                brand: String(
                    repeating: "b",
                    count: RecommendContractLimits.maximumBrandLength
                ),
                colors: Array(
                    repeating: "navy",
                    count: RecommendContractLimits.maximumColors
                ),
                material: String(
                    repeating: "m",
                    count: RecommendContractLimits.maximumMaterialLength
                )
            )
        }
        let valid = RecommendRequest(
            items: maximumItems,
            recentlyWornIds: Array(
                repeating: "0",
                count: RecommendContractLimits.maximumRecentlyWornIDs
            ),
            itemPreferences: Array(
                repeating: RecommendItemPreference(
                    id: "0",
                    averageRating: 5,
                    ratingCount: 1
                ),
                count: RecommendContractLimits.maximumItemPreferences
            ),
            occasion: String(
                repeating: "o",
                count: RecommendContractLimits.maximumOccasionLength
            )
        )
        try valid.validateForWire()

        var tooManyItems = maximumItems
        tooManyItems.append(RecommendCatalogItem(id: "overflow", name: "N", category: "top"))
        #expect(throws: RecommendRequestValidationIssue.itemCount(1_001)) {
            try RecommendRequest(
                items: tooManyItems,
                recentlyWornIds: []
            ).validateForWire()
        }

        let validCompanion = RecommendCatalogItem(id: "b", name: "B", category: "bottom")
        func request(with item: RecommendCatalogItem) -> RecommendRequest {
            RecommendRequest(items: [item, validCompanion], recentlyWornIds: [])
        }
        try request(with: RecommendCatalogItem(
            id: String(repeating: "i", count: 64),
            name: "A",
            category: "top"
        )).validateForWire()
        #expect(throws: RecommendRequestValidationIssue.emptyCatalogField(.id)) {
            try request(with: RecommendCatalogItem(
                id: "",
                name: "A",
                category: "top"
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.catalogFieldTooLong(.id)) {
            try request(with: RecommendCatalogItem(
                id: String(repeating: "i", count: 65),
                name: "A",
                category: "top"
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.emptyCatalogField(.name)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "",
                category: "top"
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.emptyCatalogField(.category)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "A",
                category: ""
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.catalogFieldTooLong(.name)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: String(repeating: "n", count: 257),
                category: "top"
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.catalogFieldTooLong(.category)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "A",
                category: String(repeating: "c", count: 65)
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.catalogFieldTooLong(.brand)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "A",
                category: "top",
                brand: String(repeating: "b", count: 129)
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.tooManyColors) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "A",
                category: "top",
                colors: Array(repeating: "navy", count: 17)
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.catalogFieldTooLong(.material)) {
            try request(with: RecommendCatalogItem(
                id: "a",
                name: "A",
                category: "top",
                material: String(repeating: "m", count: 129)
            )).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.occasionTooLong) {
            try RecommendRequest(
                items: [
                    RecommendCatalogItem(id: "a", name: "A", category: "top"),
                    validCompanion,
                ],
                recentlyWornIds: [],
                occasion: String(repeating: "o", count: 129)
            ).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.tooManyRecentlyWornIDs) {
            try RecommendRequest(
                items: [
                    RecommendCatalogItem(id: "a", name: "A", category: "top"),
                    validCompanion,
                ],
                recentlyWornIds: Array(repeating: "a", count: 1_001)
            ).validateForWire()
        }
        #expect(throws: RecommendRequestValidationIssue.tooManyItemPreferences) {
            try RecommendRequest(
                items: [
                    RecommendCatalogItem(id: "a", name: "A", category: "top"),
                    validCompanion,
                ],
                recentlyWornIds: [],
                itemPreferences: Array(
                    repeating: RecommendItemPreference(
                        id: "a",
                        averageRating: 5,
                        ratingCount: 1
                    ),
                    count: 1_001
                )
            ).validateForWire()
        }
    }

    @Test func invalidRequestIsRejectedBeforeAuthorizationOrNetwork() async {
        let authorization = RecommendRotatingAuthorization(
            initialToken: "unused",
            refreshedToken: "also-unused"
        )
        let client = RecommendClient(
            baseURL: baseURL,
            authorization: authorization,
            session: URLProtocolStub.makeSession()
        )
        URLProtocolStub.install { _ in
            Issue.record("An invalid local request must not reach the network")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }
        let invalid = RecommendRequest(
            items: [
                RecommendCatalogItem(
                    id: "a",
                    name: String(repeating: "n", count: 257),
                    category: "top"
                ),
                RecommendCatalogItem(id: "b", name: "B", category: "bottom"),
            ],
            recentlyWornIds: []
        )

        await #expect(
            throws: RecommendRequestValidationIssue.catalogFieldTooLong(.name)
        ) {
            _ = try await client.recommend(invalid)
        }
        #expect(await authorization.rejectedTokens.isEmpty)
        #expect(URLProtocolStub.captured.isEmpty)
    }
}

private actor RecommendRotatingAuthorization: BackendAuthorizing {
    private let initialToken: String
    private let refreshedToken: String
    private(set) var rejectedTokens: [String?] = []

    init(initialToken: String, refreshedToken: String) {
        self.initialToken = initialToken
        self.refreshedToken = refreshedToken
    }

    func accessToken(rejecting rejectedToken: String?) -> String {
        rejectedTokens.append(rejectedToken)
        return rejectedToken == nil ? initialToken : refreshedToken
    }
}

private actor RecommendSuspendedAuthorization: BackendAuthorizing {
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var tokenContinuation: CheckedContinuation<String, Error>?

    func accessToken(rejecting rejectedToken: String?) async throws -> String {
        didStart = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters.removeAll()
        return try await withCheckedThrowingContinuation { continuation in
            tokenContinuation = continuation
        }
    }

    func waitUntilRequested() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func resume(with token: String) {
        tokenContinuation?.resume(returning: token)
        tokenContinuation = nil
    }
}

private actor RecommendRetiredBearerAuthorization: BackendAuthorizing {
    private let retiredToken: String
    private(set) var rejectedTokens: [String?] = []
    private(set) var replacementTokenCount = 0

    init(retiredToken: String) {
        self.retiredToken = retiredToken
    }

    func accessToken(rejecting rejectedToken: String?) throws -> String {
        rejectedTokens.append(rejectedToken)
        guard let rejectedToken else { return retiredToken }
        guard rejectedToken != retiredToken else {
            throw AppAttestAuthorizationError.retiredSession
        }
        replacementTokenCount += 1
        return "unexpected-replacement-token"
    }
}
