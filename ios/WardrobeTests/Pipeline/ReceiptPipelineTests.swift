import Foundation
import SwiftData
import Testing

@testable import Wardrobe

/// End-to-end pipeline tests with a stubbed URLSession (used for both the Gmail
/// client and the backend client) and an in-memory SwiftData container. The
/// `URLProtocolStub.install` handler dispatches by request host: Gmail traffic
/// goes to gmail.googleapis.com, /extract traffic goes to test.local.
///
/// The handler closure **must not capture `self`** — URLSession dispatches it
/// off the main actor and any access to MainActor-isolated state from there
/// crashes silently mid-test. Everything the closure needs (Data, hosts) is
/// captured as a local Sendable value before installing.
@MainActor
struct ReceiptPipelineTests {
    private enum FixtureError: Error { case saveFailed, missingBackendRequest }

    private struct AllowPrivacyGate: PrivacyGateChecking {
        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            .allowed
        }
    }

    private struct DenyPrivacyGate: PrivacyGateChecking {
        let denial: PrivacyGateDenial

        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            .denied(denial)
        }
    }

    private struct CancellationAfterListTransport: GmailTransport {
        let listJSON: Data

        func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            if request.url?.path.hasSuffix("/messages") == true {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (listJSON, response)
            }
            throw CancellationError()
        }
    }

    // The user wants *all* orders, so the default query must not clamp recency —
    // guard against a date window creeping back into it.
    @Test func defaultQueryHasNoDateWindow() {
        #expect(!ReceiptPipeline.defaultQuery.contains("newer_than"))
        #expect(!ReceiptPipeline.defaultQuery.contains("older_than"))
    }

    // `nonisolated` lets the URLProtocol callbacks (off-main) read these without
    // crossing actor boundaries. All values are immutable / Sendable.
    nonisolated private static let backendURL = URL(string: "http://test.local")!
    nonisolated private static let gmailHost = "gmail.googleapis.com"
    nonisolated private static let backendHost = "test.local"

    nonisolated private static let receiptSender = "orders@everlane.com"
    nonisolated private static let receiptSubject = "Order #ABC1234 confirmed"
    nonisolated private static let receiptBody = """
        Thanks for your order from Everlane!

        1x Classic Oxford Shirt - White - $78.00

        Order Total: $78.00 USD
        """
    nonisolated private static let marketingSender = "hello@marketingcorp.example"
    nonisolated private static let marketingSubject = "Flash sale ends tonight — 50% off everything!"
    nonisolated private static let marketingBody =
        "Don't miss our exclusive offer. Shop now and save 50%. Limited time."

    // MARK: - Helpers

    /// Returns the container *and* the context. Tests must hold the container in
    /// a local variable for the lifetime of the test — `ModelContext` doesn't
    /// strongly retain its container, so dropping it on the floor lets the
    /// container deallocate mid-test and the next SwiftData call SIGTRAPs.
    private static func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeInMemory()
    }

    private static func makeClients() -> (GmailReadOnlyClient, ExtractClient) {
        let session = URLProtocolStub.makeSession()
        let gmail = GmailReadOnlyClient(
            transport: URLSessionGmailTransport(session: session),
            auth: StaticTokenAuth(token: "test-token")
        )
        let extractClient = ExtractClient(
            baseURL: backendURL,
            deviceToken: "test-device-token",
            session: session
        )
        return (gmail, extractClient)
    }

    /// Builds a fresh 200 HTTPURLResponse — `nonisolated` so it's safe to call
    /// from the URLProtocol callback queue.
    nonisolated private static func ok(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    nonisolated private static func error(
        _ status: Int,
        for request: URLRequest
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func capturedBackendRequest() throws -> ExtractRequest {
        guard let index = URLProtocolStub.captured.firstIndex(where: {
            $0.url?.host == backendHost
        }), URLProtocolStub.capturedBodies.indices.contains(index) else {
            throw FixtureError.missingBackendRequest
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(
            ExtractRequest.self,
            from: URLProtocolStub.capturedBodies[index]
        )
    }

    // MARK: - Tests

    @Test func manualSyncWithoutConsentMakesNoGmailOrBackendRequest() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        context.insert(Item(name: "Existing tee", category: "top", source: .email))
        try context.save()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: DenyPrivacyGate(denial: .receiptConsentRequired),
            privacySubjectID: .external("pipeline-tests")
        )
        URLProtocolStub.install { _ in
            Issue.record("A denied sync must not make a request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case .failed(let message) = pipeline.state else {
            Issue.record("Expected failed privacy state, got \(pipeline.state)")
            return
        }
        #expect(message.contains("Review data use"))
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    @Test func backgroundSyncRequiresBothConsentAndAutomationPreference() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: DenyPrivacyGate(denial: .backgroundReceiptSyncDisabled),
            privacySubjectID: .external("pipeline-tests")
        )
        URLProtocolStub.install { _ in
            Issue.record("A disabled background sync must not make a request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10, mode: .background)

        guard case .failed(let message) = pipeline.state else {
            Issue.record("Expected failed privacy state, got \(pipeline.state)")
            return
        }
        #expect(message.contains("turned off"))
        #expect(URLProtocolStub.captured.isEmpty)
    }

    @Test func cancelledBeforeSyncMakesNoRequestAndIsNotReportedAsSuccess() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        URLProtocolStub.install { _ in
            Issue.record("A pre-cancelled sync must not make a request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        let work = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await pipeline.sync(query: "test", maxMessages: 10, mode: .background)
        }
        await work.value

        #expect(pipeline.state == .failed(message: "Receipt sync was cancelled."))
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
    }

    @Test func cancellationDuringPerMessageWorkStopsWithoutCountingAnErrorOrCompleting() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (_, extractClient) = Self.makeClients()
        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_cancelled", "m_never"])
        let gmail = GmailReadOnlyClient(
            transport: CancellationAfterListTransport(listJSON: listJSON),
            auth: StaticTokenAuth(token: "test-token")
        )
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        URLProtocolStub.install { @Sendable request in
            Issue.record("Cancellation must stop before a backend request")
            throw URLError(.cancelled)
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10, mode: .background)

        #expect(pipeline.state == .failed(message: "Receipt sync was cancelled."))
        #expect(URLProtocolStub.captured.isEmpty)
        #expect(try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
    }

    @Test func ingestsFashionItemFromSingleReceipt() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m1"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "m1",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m1",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m1") {
                    return (Self.ok(for: request), messageJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 1)
        #expect(candidates == 1)
        #expect(errors == 0)

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.name == "Classic Oxford Shirt")
        #expect(items.first?.brand == "Everlane")
        #expect(items.first?.category == "top")
        #expect(items.first?.source == .email)
        #expect(items.first?.sourceMsgId == "m1")
        #expect(items.first?.accountSubjectKey
            == WardrobeAccountScope.external(.external("pipeline-tests")).rawValue)
    }

    @Test func persistsImageURLFromExtraction() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m1"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "m1",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let imageURL = "https://cdn.example.com/oxford-shirt.jpg"
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m1",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0,
            imageURL: imageURL
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m1") {
                    return (Self.ok(for: request), messageJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.imageURL == imageURL)
    }

    @Test func backendRequestUsesRedactedProductExcerptAndSenderDomainOnly() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let id = "gmail-source-private-42"
        let listJSON = try PipelineFixtures.messageListJSON(ids: [id])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: id,
            sender: #""Orders" <orders@shop.example>"#,
            subject: "Order #ABC-123456 for taylor@example.com",
            body: """
                1x Classic Oxford Shirt - White - $78.00
                Size: M
                Order Number: ABC-123456
                Email: taylor@example.com
                Phone: +65 9123 4567
                Visa ending in 4242
                Shipping Address
                123 Orchard Road
                Singapore 238888
                Unsubscribe
                """,
            labels: ["CATEGORY_PURCHASES"]
        )
        let responseJSON = try PipelineFixtures.extractNotFashionResponseJSON(sourceMsgId: id)
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), responseJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)
        let request = try Self.capturedBackendRequest()

        // The source id remains only in the compatibility envelope. It is not
        // copied into the model-visible metadata or product excerpt.
        #expect(request.sourceMsgId == id)
        #expect(request.sender == "shop.example")
        #expect(request.subject == "Order [redacted] for [redacted]")
        #expect(request.snippet.contains("Classic Oxford Shirt"))
        #expect(request.snippet.contains("Size: M"))
        #expect(!request.snippet.contains(id))
        #expect(!request.snippet.contains("orders@"))
        #expect(!request.snippet.contains("taylor@example.com"))
        #expect(!request.snippet.contains("9123"))
        #expect(!request.snippet.contains("4242"))
        #expect(!request.snippet.contains("ABC-123456"))
        #expect(!request.snippet.contains("123 Orchard"))
        #expect(!request.snippet.contains("238888"))
        #expect(request.snippet.count <= ReceiptPayloadBuilder.maximumSnippetCharacters)
    }

    @Test func backendRequestNeverSendsTokenizedURLsOrSeparatorIdentifiers() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let id = "url-privacy-boundary"
        let listJSON = try PipelineFixtures.messageListJSON(ids: [id])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: id,
            sender: #""Orders" <orders@shop.example>"#,
            subject: "Order AB_12345 Invoice INV/2026/001 Tracking TRK.2026.08 — Order Summary",
            body: """
                1x Wool Coat - Camel - $320.00 https://shop.example/orders/AB_12345?token=TOPSECRET#private
                Product: Wool Belt www.shop.example/track/TRK.2026.08?auth=PRIVATE456
                Invoice INV/2026/001 for Wool Coat
                """,
            labels: ["CATEGORY_PURCHASES"]
        )
        let responseJSON = try PipelineFixtures.extractNotFashionResponseJSON(sourceMsgId: id)
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), responseJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)
        let request = try Self.capturedBackendRequest()

        #expect(
            request.subject
                == "Order [redacted] Invoice [redacted] Tracking [redacted] — Order Summary"
        )
        #expect(request.snippet.contains("1x Wool Coat - Camel - $320.00"))
        #expect(request.snippet.contains("Product: Wool Belt"))
        #expect(request.snippet.contains("Invoice [redacted] for Wool Coat"))
        #expect(!request.snippet.localizedCaseInsensitiveContains("https://"))
        #expect(!request.snippet.localizedCaseInsensitiveContains("www."))
        #expect(!request.snippet.localizedCaseInsensitiveContains("shop.example"))
        #expect(!request.snippet.contains("/orders/"))
        #expect(!request.snippet.localizedCaseInsensitiveContains("token="))
        #expect(!request.snippet.contains("TOPSECRET"))
        #expect(!request.snippet.localizedCaseInsensitiveContains("auth="))
        #expect(!request.snippet.contains("PRIVATE456"))
        #expect(!request.snippet.contains("AB_12345"))
        #expect(!request.snippet.contains("INV/2026/001"))
        #expect(!request.snippet.contains("TRK.2026.08"))
        #expect(!request.snippet.contains(id))
    }

    @Test func backendRequestPrefersJSONLDAndNeverIncludesRawPlainBody() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let id = "structured-source-id"
        let listJSON = try PipelineFixtures.messageListJSON(ids: [id])
        let messageJSON = try PipelineFixtures.multipartMessageJSON(
            id: id,
            sender: "receipts@everlane.com",
            subject: "Your order #STRUCT-98765",
            plainBody: """
                RAW-PLAIN-BODY-MARKER
                Taylor Example, taylor@example.com, +65 9123 4567
                123 Orchard Road, Singapore 238888
                Visa ending in 4242
                """,
            htmlBody: """
                <script type="application/ld+json">
                {
                  "@type":"Product",
                  "name":"Linen Camp Shirt",
                  "brand":{"name":"Everlane"},
                  "offers":{"price":"88.00","priceCurrency":"USD"}
                }
                </script>
                """,
            labels: ["CATEGORY_PURCHASES"]
        )
        let responseJSON = try PipelineFixtures.extractNotFashionResponseJSON(sourceMsgId: id)
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), responseJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)
        let request = try Self.capturedBackendRequest()
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(request.snippet.utf8)) as? [String: Any]
        )

        #expect(object["format"] as? String == "schema.org-products-v1")
        #expect(request.snippet.contains("Linen Camp Shirt"))
        #expect(!request.snippet.contains("RAW-PLAIN-BODY-MARKER"))
        #expect(!request.snippet.contains("taylor@example.com"))
        #expect(!request.snippet.contains("123 Orchard"))
        #expect(!request.snippet.contains(id))
    }

    @Test func skipsMarketingEmailAtTier0() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_marketing"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "m_marketing",
            sender: Self.marketingSender,
            subject: Self.marketingSubject,
            body: Self.marketingBody,
            labels: ["INBOX", "CATEGORY_PROMOTIONS"]
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m_marketing") {
                    return (Self.ok(for: request), messageJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                // Pipeline should not reach /extract for a marketing email.
                throw URLError(.unsupportedURL)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 0)
        #expect(candidates == 0)
        #expect(errors == 0)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.isEmpty)
        let processed = try context.fetch(FetchDescriptor<ProcessedGmailMessage>())
        #expect(processed.count == 1)
        #expect(processed.first?.outcome == .notPurchase)
    }

    @Test func mixedBatchOnlyExtractsFashionMessages() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_fashion", "m_marketing"])
        let fashionJSON = try PipelineFixtures.messageJSON(
            id: "m_fashion",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let marketingJSON = try PipelineFixtures.messageJSON(
            id: "m_marketing",
            sender: Self.marketingSender,
            subject: Self.marketingSubject,
            body: Self.marketingBody,
            labels: ["INBOX", "CATEGORY_PROMOTIONS"]
        )
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m_fashion",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m_fashion") {
                    return (Self.ok(for: request), fashionJSON)
                }
                if path.contains("/messages/m_marketing") {
                    return (Self.ok(for: request), marketingJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 1)
        #expect(candidates == 1)
        #expect(errors == 0)
    }

    @Test func notFashionResponseAddsNoItems() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_books"])
        let bookReceipt = try PipelineFixtures.messageJSON(
            id: "m_books",
            sender: "orders@example-bookshop.com",
            subject: "Your order #BOOK99 has been confirmed",
            body: "Thanks for your order. 1x Programming Book - $24.00",
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let notFashionJSON = try PipelineFixtures.extractNotFashionResponseJSON(
            sourceMsgId: "m_books"
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m_books") {
                    return (Self.ok(for: request), bookReceipt)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), notFashionJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)
        guard case let .complete(added, candidates, _) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 0)
        #expect(candidates == 1)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.isEmpty)
        let processed = try context.fetch(FetchDescriptor<ProcessedGmailMessage>())
        #expect(processed.count == 1)
        #expect(processed.first?.outcome == .notFashion)
    }

    @Test func candidateWithoutSafeProductContentIsLedgeredWithoutBackendRequest() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let listJSON = try PipelineFixtures.messageListJSON(ids: ["empty-safe-payload"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "empty-safe-payload",
            sender: "orders@example.com",
            subject: "Your order is confirmed",
            body: "Thanks. Contact customer service if you have any questions.",
            labels: ["CATEGORY_PURCHASES"]
        )
        let handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?) = {
            @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                Issue.record("Empty safe payload must not reach the backend")
                throw URLError(.unsupportedURL)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        URLProtocolStub.install(handler)

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            URLProtocolStub.reset()
            return
        }
        #expect(added == 0)
        #expect(candidates == 1)
        #expect(errors == 0)
        let entry = try #require(
            context.fetch(FetchDescriptor<ProcessedGmailMessage>()).first
        )
        #expect(entry.outcome == .emptyContent)

        URLProtocolStub.reset()
        URLProtocolStub.install(handler)
        defer { URLProtocolStub.reset() }
        await pipeline.sync(query: "test", maxMessages: 10)
        #expect(URLProtocolStub.captured.count == 1)
        #expect(URLProtocolStub.captured.first?.url?.path.hasSuffix("/messages") == true)
    }

    @Test func backendFailureIsNotLedgeredAndNextSyncRetriesTheMessage() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let listJSON = try PipelineFixtures.messageListJSON(ids: ["retry-backend"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "retry-backend",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["CATEGORY_PURCHASES"]
        )
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.error(503, for: request), Data("unavailable".utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }
        await pipeline.sync(query: "test", maxMessages: 10)
        guard case let .complete(_, _, firstErrors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            URLProtocolStub.reset()
            return
        }
        #expect(firstErrors == 1)
        #expect(try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)

        let notFashion = try PipelineFixtures.extractNotFashionResponseJSON(
            sourceMsgId: "retry-backend"
        )
        URLProtocolStub.reset()
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), notFashion)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        #expect(URLProtocolStub.captured.count == 3)
        let entry = try #require(
            context.fetch(FetchDescriptor<ProcessedGmailMessage>()).first
        )
        #expect(entry.outcome == .notFashion)
    }

    @Test(arguments: [true, false])
    func semanticallyInvalidExtractionIsNotLedgeredAndNextSyncRetriesTheMessage(
        isFashion: Bool
    ) async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )
        let messageID = isFashion
            ? "retry-empty-fashion"
            : "retry-non-fashion-with-items"
        let listJSON = try PipelineFixtures.messageListJSON(ids: [messageID])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: messageID,
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["CATEGORY_PURCHASES"]
        )
        let invalidExtractionJSON = if isFashion {
            try PipelineFixtures.extractEmptyFashionResponseJSON(sourceMsgId: messageID)
        } else {
            try PipelineFixtures.extractNonFashionWithItemsResponseJSON(sourceMsgId: messageID)
        }
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), invalidExtractionJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(firstAdded, firstCandidates, firstErrors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            URLProtocolStub.reset()
            return
        }
        #expect(firstAdded == 0)
        #expect(firstCandidates == 0)
        #expect(firstErrors == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)

        let validFashionJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: messageID,
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78
        )
        URLProtocolStub.reset()
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), validFashionJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        #expect(URLProtocolStub.captured.count == 3)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
        let entry = try #require(
            context.fetch(FetchDescriptor<ProcessedGmailMessage>()).first
        )
        #expect(entry.outcome == .imported)
    }

    @Test func failedAtomicSaveRollsBackItemAndLedgerAndRemainsRetryable() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        context.autosaveEnabled = false
        let (gmail, extractClient) = Self.makeClients()
        let subject = PrivacySubjectID.external("pipeline-tests")
        let failingStore = GmailProcessedStateStore(
            modelContext: context,
            subjectID: subject,
            save: { _ in throw FixtureError.saveFailed }
        )
        let failingPipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: subject,
            processedStateStore: failingStore
        )
        let listJSON = try PipelineFixtures.messageListJSON(ids: ["retry-save"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "retry-save",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["CATEGORY_PURCHASES"]
        )
        let fashionJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "retry-save",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78
        )
        let handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?) = {
            @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                if request.url?.path.hasSuffix("/messages") == true {
                    return (Self.ok(for: request), listJSON)
                }
                return (Self.ok(for: request), messageJSON)
            case Self.backendHost:
                return (Self.ok(for: request), fashionJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        URLProtocolStub.install(handler)
        await failingPipeline.sync(query: "test", maxMessages: 10)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
        #expect(!context.hasChanges)

        let retryPipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: subject
        )
        URLProtocolStub.reset()
        URLProtocolStub.install(handler)
        defer { URLProtocolStub.reset() }
        await retryPipeline.sync(query: "test", maxMessages: 10)

        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
        let entry = try #require(
            context.fetch(FetchDescriptor<ProcessedGmailMessage>()).first
        )
        #expect(entry.outcome == .imported)
    }

    @Test func reSyncIsIdempotentForSameMessage() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m1"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "m1",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m1",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )

        let handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?) = { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m1") {
                    return (Self.ok(for: request), messageJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }

        URLProtocolStub.install(handler)
        await pipeline.sync(query: "test", maxMessages: 10)
        URLProtocolStub.reset()

        URLProtocolStub.install(handler)
        defer { URLProtocolStub.reset() }
        await pipeline.sync(query: "test", maxMessages: 10)

        // The processed ledger filters the message before messages.get: the
        // second run performs one cheap list request and no get/backend call.
        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 0)
        #expect(candidates == 0)
        #expect(errors == 0)
        #expect(URLProtocolStub.captured.count == 1)
        #expect(URLProtocolStub.captured.first?.url?.path.hasSuffix("/messages") == true)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        let processed = try context.fetch(FetchDescriptor<ProcessedGmailMessage>())
        #expect(processed.count == 1)
        #expect(processed.first?.outcome == .imported)
    }

    @Test func gmailGetMessageErrorCountsAsErrorButContinues() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_broken", "m_good"])
        let goodJSON = try PipelineFixtures.messageJSON(
            id: "m_good",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m_good",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m_broken") {
                    return (Self.error(500, for: request), Data(#"{"error":"broken"}"#.utf8))
                }
                if path.contains("/messages/m_good") {
                    return (Self.ok(for: request), goodJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)
        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 1)
        #expect(candidates == 1)
        #expect(errors == 1)
        let processedIDs = Set(
            try context.fetch(FetchDescriptor<ProcessedGmailMessage>()).map(\.gmailMessageID)
        )
        #expect(processedIDs == ["m_good"])
        #expect(!processedIDs.contains("m_broken"))
    }

    /// One order spread across two emails (confirmation + dispatch) listing the
    /// same product must collapse to a single catalog item — the real bug behind
    /// the duplicate Maison Kitsuné entries. Dedup is catalog-wide on identity,
    /// not per-`sourceMsgId`, so the second email's identical item is skipped.
    @Test func sameProductAcrossTwoEmailsDedupesToOneItem() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: ["m_confirm", "m_ship"])
        let confirmJSON = try PipelineFixtures.messageJSON(
            id: "m_confirm",
            sender: Self.receiptSender,
            subject: "Order #ABC1234 confirmed",
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let shipJSON = try PipelineFixtures.messageJSON(
            id: "m_ship",
            sender: Self.receiptSender,
            subject: "Your order #ABC1234 has shipped",
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        // Both emails extract the same product (identical brand+name+category).
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "m_confirm",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )

        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/m_confirm") {
                    return (Self.ok(for: request), confirmJSON)
                }
                if path.contains("/messages/m_ship") {
                    return (Self.ok(for: request), shipJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 1)        // one product, despite two candidate emails
        #expect(candidates == 2)
        #expect(errors == 0)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        let outcomes = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<ProcessedGmailMessage>())
                .map { ($0.gmailMessageID, $0.outcome) }
        )
        #expect(outcomes["m_confirm"] == .imported)
        #expect(outcomes["m_ship"] == .duplicate)
    }

    @Test func sameProductInAnotherAccountDoesNotSuppressOrGetHealedByActiveAccount() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let activeSubject = PrivacySubjectID.external("active-account")
        let otherScope = WardrobeAccountScope.external(.external("other-account"))
        context.insert(Item(
            name: "Classic Oxford Shirt",
            category: "top",
            brand: "Everlane",
            source: .email,
            sourceMsgId: "other-message",
            accountSubjectKey: otherScope.rawValue
        ))
        try context.save()

        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: activeSubject
        )
        let listJSON = try PipelineFixtures.messageListJSON(ids: ["active-message"])
        let messageJSON = try PipelineFixtures.messageJSON(
            id: "active-message",
            sender: Self.receiptSender,
            subject: Self.receiptSubject,
            body: Self.receiptBody,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let extractJSON = try PipelineFixtures.extractFashionResponseJSON(
            sourceMsgId: "active-message",
            itemName: "Classic Oxford Shirt",
            brand: "Everlane",
            price: 78.0
        )
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                let path = request.url?.path ?? ""
                if path.hasSuffix("/messages") {
                    return (Self.ok(for: request), listJSON)
                }
                if path.contains("/messages/active-message") {
                    return (Self.ok(for: request), messageJSON)
                }
                throw URLError(.unsupportedURL)
            case Self.backendHost:
                return (Self.ok(for: request), extractJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 1)
        #expect(candidates == 1)
        #expect(errors == 0)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 2)
        #expect(Set(items.compactMap(\.accountSubjectKey)) == [
            otherScope.rawValue,
            WardrobeAccountScope.external(activeSubject).rawValue,
        ])
    }

    /// Duplicates already in the store (from before dedup went catalog-wide) are
    /// healed by the up-front sweep, while a same-identity *manual* item — which
    /// is user-curated — is left untouched.
    @Test func sweepHealsPreExistingEmailDuplicatesButKeepsManual() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let pipelineScope = WardrobeAccountScope.external(.external("pipeline-tests"))
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .email, sourceMsgId: "confirm",
            accountSubjectKey: pipelineScope.rawValue
        ))
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .email, sourceMsgId: "ship",
            accountSubjectKey: pipelineScope.rawValue
        ))
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .manual
        ))
        context.insert(Item(
            name: "Wool Scarf", category: "accessory", brand: "Acme", source: .email,
            sourceMsgId: "scarf", accountSubjectKey: pipelineScope.rawValue
        ))
        try context.save()

        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context,
            privacyGate: AllowPrivacyGate(),
            privacySubjectID: .external("pipeline-tests")
        )

        let listJSON = try PipelineFixtures.messageListJSON(ids: [])
        URLProtocolStub.install { @Sendable request in
            switch request.url?.host {
            case Self.gmailHost:
                return (Self.ok(for: request), listJSON)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        defer { URLProtocolStub.reset() }

        await pipeline.sync(query: "test", maxMessages: 10)

        let items = try context.fetch(FetchDescriptor<Item>())
        // 2 email Fox dupes → 1; manual Fox kept; scarf kept ⇒ 3 total.
        #expect(items.count == 3)
        let emailFox = items.filter { $0.name == "Gallery Fox Tee" && $0.source == .email }
        #expect(emailFox.count == 1)
        let manualFox = items.filter { $0.name == "Gallery Fox Tee" && $0.source == .manual }
        #expect(manualFox.count == 1)
    }
}
