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
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Item.self, Outfit.self, WearLog.self,
            configurations: config
        )
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

    // MARK: - Tests

    @Test func ingestsFashionItemFromSingleReceipt() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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
    }

    @Test func persistsImageURLFromExtraction() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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

    @Test func skipsMarketingEmailAtTier0() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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
    }

    @Test func mixedBatchOnlyExtractsFashionMessages() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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
            modelContext: context
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
    }

    @Test func reSyncIsIdempotentForSameMessage() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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

        // Second sync should add zero (catalog-wide identity dedup).
        guard case let .complete(added, candidates, errors) = pipeline.state else {
            Issue.record("Expected .complete, got \(pipeline.state)")
            return
        }
        #expect(added == 0)
        #expect(candidates == 1)
        #expect(errors == 0)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
    }

    @Test func gmailGetMessageErrorCountsAsErrorButContinues() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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
            modelContext: context
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
    }

    /// Duplicates already in the store (from before dedup went catalog-wide) are
    /// healed by the up-front sweep, while a same-identity *manual* item — which
    /// is user-curated — is left untouched.
    @Test func sweepHealsPreExistingEmailDuplicatesButKeepsManual() async throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .email, sourceMsgId: "confirm"
        ))
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .email, sourceMsgId: "ship"
        ))
        context.insert(Item(
            name: "Gallery Fox Tee", category: "top", brand: "Maison Kitsuné",
            source: .manual
        ))
        context.insert(Item(
            name: "Wool Scarf", category: "accessory", brand: "Acme", source: .email,
            sourceMsgId: "scarf"
        ))
        try context.save()

        let (gmail, extractClient) = Self.makeClients()
        let pipeline = ReceiptPipeline(
            gmailClient: gmail,
            extractClient: extractClient,
            modelContext: context
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
