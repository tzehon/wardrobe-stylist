import Foundation
import Testing

@testable import Wardrobe

struct CandidateClassifierTests {

    private func signals(
        sender: String? = nil,
        domain: String? = nil,
        subject: String = "",
        body: String = "",
        labels: [String] = ["INBOX"],
        hasAttachments: Bool = false
    ) -> CandidateSignals {
        CandidateSignals(
            senderAddress: sender,
            senderDomain: domain,
            subject: subject,
            bodyText: body,
            labels: labels,
            hasAttachments: hasAttachments
        )
    }

    @Test func fashionPurchaseFromKnownRetailerScoresHigh() {
        let s = signals(
            sender: "orders@everlane.com",
            domain: "everlane.com",
            subject: "Order #ABC1234 confirmed",
            body: "Thanks for your order. Total: $78.00. We'll send tracking when it ships.",
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let result = CandidateClassifier.classify(s)
        #expect(result.likelyPurchase)
        #expect(result.score >= 0.8)
        #expect(result.reasons.contains("label:CATEGORY_PURCHASES"))
        #expect(result.reasons.contains("retailer:everlane.com"))
        #expect(result.reasons.contains("transactional-sender:orders"))
        #expect(result.reasons.contains("order-number"))
    }

    @Test func gmailCategoryPurchasesLabelAloneFlagsLikely() {
        // Even with nothing else, Gmail's automatic purchases label is strong enough.
        let result = CandidateClassifier.classify(
            signals(subject: "", body: "", labels: ["CATEGORY_PURCHASES"])
        )
        #expect(result.likelyPurchase)
        #expect(result.score >= 0.5)
    }

    @Test func marketingFlashSaleFromKnownRetailerStaysBelowThreshold() {
        // From a known retailer, but the language is clearly marketing.
        let s = signals(
            sender: "hello@everlane.com",
            domain: "everlane.com",
            subject: "Flash Sale! 50% off ends tonight",
            body: "Shop now — exclusive offer just for you. Limited time.",
            labels: ["INBOX", "CATEGORY_PROMOTIONS"]
        )
        let result = CandidateClassifier.classify(s)
        #expect(!result.likelyPurchase, "got score=\(result.score) reasons=\(result.reasons)")
    }

    @Test func subdomainOfKnownRetailerStillMatches() {
        let s = signals(
            sender: "orders@us.everlane.com",
            domain: "us.everlane.com",
            subject: "Order confirmed",
            labels: ["INBOX"]
        )
        let result = CandidateClassifier.classify(s)
        #expect(result.reasons.contains("retailer:us.everlane.com"))
        #expect(result.likelyPurchase)
    }

    @Test func shippingNotificationFlagsLikely() {
        let s = signals(
            sender: "shipping@madewell.com",
            domain: "madewell.com",
            subject: "Your order has shipped",
            body: "Your package is out for delivery. Tracking number: 1Z999..."
        )
        let result = CandidateClassifier.classify(s)
        #expect(result.likelyPurchase)
        #expect(result.reasons.contains("shipping"))
    }

    @Test func emptyInputScoresZero() {
        let result = CandidateClassifier.classify(signals(labels: []))
        #expect(result.score == 0)
        #expect(!result.likelyPurchase)
        #expect(result.reasons.isEmpty)
    }

    @Test func scoreIsBoundedToZeroOne() {
        // Pile on every positive signal; should clamp at 1.0.
        let s = signals(
            sender: "orders@everlane.com",
            domain: "everlane.com",
            subject: "Receipt for your order #ABC1234",
            body: "Total: $99.00. Your package has shipped. Tracking number attached.",
            labels: ["INBOX", "CATEGORY_PURCHASES"],
            hasAttachments: true
        )
        let result = CandidateClassifier.classify(s)
        #expect(result.score <= 1.0)
        #expect(result.score > 0.9)
    }

    @Test func customThresholdChangesGate() {
        // Same signals, two thresholds — one accepts, the other rejects.
        let s = signals(
            sender: "support@unknown-brand.example",
            domain: "unknown-brand.example",
            subject: "Your order",
            labels: ["INBOX"]
        )
        let easy = CandidateClassifier.classify(s, threshold: 0.2)
        let strict = CandidateClassifier.classify(s, threshold: 0.8)
        #expect(easy.likelyPurchase)
        #expect(!strict.likelyPurchase)
        #expect(easy.score == strict.score)  // threshold doesn't affect the score itself
    }

    @Test func orderNumberPatternFiresOnHashId() {
        let s = signals(subject: "Confirmation #ZX98YT", labels: ["INBOX"])
        let result = CandidateClassifier.classify(s)
        #expect(result.reasons.contains("order-number"))
    }

    @Test func promoPenaltyIsCapped() {
        // Many promo markers — penalty should still cap at -0.3.
        let s = signals(
            subject: "% off flash sale exclusive offer shop now last chance",
            body: "Ends tonight! Limited time! Deal of the day!",
            labels: ["INBOX", "CATEGORY_PROMOTIONS"]
        )
        let result = CandidateClassifier.classify(s)
        #expect(result.score == 0, "score=\(result.score) reasons=\(result.reasons)")
    }
}
