import Foundation
import Testing

@testable import Wardrobe

struct SignalsExtractorTests {
    private let decoder = JSONDecoder()

    @Test func parseSenderWithDisplayName() {
        let r = SignalsExtractor.parseSender(#""Everlane Orders" <orders@everlane.com>"#)
        #expect(r.address == "orders@everlane.com")
        #expect(r.domain == "everlane.com")
    }

    @Test func parseSenderBareAddress() {
        let r = SignalsExtractor.parseSender("orders@Everlane.com")
        #expect(r.address == "orders@everlane.com")  // lowercased
        #expect(r.domain == "everlane.com")
    }

    @Test func parseSenderMalformedReturnsNil() {
        #expect(SignalsExtractor.parseSender(nil).address == nil)
        #expect(SignalsExtractor.parseSender("").address == nil)
        #expect(SignalsExtractor.parseSender("not-an-email").address == nil)
        #expect(SignalsExtractor.parseSender("@nodomain.com").address == nil)
        #expect(SignalsExtractor.parseSender("nolocal@").address == nil)
    }

    @Test func makeSignalsFromMultipartFixture() throws {
        // Reuses the multipart fixture from Phase 1a — orders@retailer.com,
        // subject "Order #98765 confirmed", text/plain body, with attachment.
        let msg = try decoder.decode(
            GmailMessage.self,
            from: Data(GmailFixtures.messageMultipartJSON.utf8)
        )
        let s = SignalsExtractor.makeSignals(from: msg)
        #expect(s.senderAddress == "orders@retailer.com")
        #expect(s.senderDomain == "retailer.com")
        #expect(s.subject == "Order #98765 confirmed")
        #expect(s.bodyText == "Hello, world!")
        #expect(s.hasAttachments)
        #expect(s.labels.contains("INBOX"))
    }

    @Test func extractorPlusClassifierGiveCoherentScore() throws {
        let msg = try decoder.decode(
            GmailMessage.self,
            from: Data(GmailFixtures.messageMultipartJSON.utf8)
        )
        let result = CandidateClassifier.classify(SignalsExtractor.makeSignals(from: msg))
        // The fixture lacks CATEGORY_PURCHASES and the domain isn't a known
        // retailer, but the transactional sender, subject marker, order-number
        // pattern, and attachment combine to clear the default threshold.
        #expect(result.likelyPurchase, "score=\(result.score) reasons=\(result.reasons)")
    }
}
