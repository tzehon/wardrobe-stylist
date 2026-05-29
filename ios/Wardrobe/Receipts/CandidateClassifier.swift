import Foundation

/// Bundle of on-device signals extracted from one Gmail message. Holds nothing
/// the user wouldn't expect to be on-device (no auth, no message ids beyond
/// what fits in this struct), and the classifier reads it without any I/O.
struct CandidateSignals: Equatable, Sendable {
    var senderAddress: String?
    var senderDomain: String?
    var subject: String
    var bodyText: String
    var labels: [String]
    var hasAttachments: Bool

    init(
        senderAddress: String? = nil,
        senderDomain: String? = nil,
        subject: String = "",
        bodyText: String = "",
        labels: [String] = [],
        hasAttachments: Bool = false
    ) {
        self.senderAddress = senderAddress
        self.senderDomain = senderDomain
        self.subject = subject
        self.bodyText = bodyText
        self.labels = labels
        self.hasAttachments = hasAttachments
    }
}

/// Output of `CandidateClassifier.classify`. `score` is bounded to `[0, 1]`;
/// `likelyPurchase` is the gate decision; `reasons` is the (test- and
/// debug-readable) list of contributing signals.
struct CandidateScore: Equatable, Sendable {
    var likelyPurchase: Bool
    var score: Double
    var reasons: [String]
}

/// Pure, deterministic, fast scorer that decides whether an email *looks* like
/// a purchase receipt — Tier 0 of the extraction pipeline. Non-receipts never
/// leave the device because they never get past this gate.
enum CandidateClassifier {

    /// Default cut-off above which an email is treated as a candidate. Exposed
    /// so tests can probe the boundary without rewriting fixtures.
    static let defaultThreshold: Double = 0.5

    static func classify(
        _ signals: CandidateSignals,
        threshold: Double = defaultThreshold
    ) -> CandidateScore {
        var score: Double = 0
        var reasons: [String] = []

        let subject = signals.subject.lowercased()
        let body = signals.bodyText.lowercased()
        let combined = subject + "\n" + body

        // 1. Gmail's CATEGORY_PURCHASES is an automatic transactional label — strong signal.
        if signals.labels.contains("CATEGORY_PURCHASES") {
            score += 0.6
            reasons.append("label:CATEGORY_PURCHASES")
        }

        // 2. Known retailer in the sender domain.
        if let domain = signals.senderDomain,
           RetailerDirectory.isKnownRetailer(domain: domain) {
            score += 0.25
            reasons.append("retailer:\(domain)")
        }

        // 3. Transactional sender local-part (orders@, receipts@, billing@, ...).
        if let address = signals.senderAddress?.lowercased(),
           let local = address.split(separator: "@", maxSplits: 1).first,
           RetailerDirectory.isTransactionalLocalPart(String(local)) {
            score += 0.15
            reasons.append("transactional-sender:\(local)")
        }

        // 4. Subject markers — phrases that almost always mean "transactional".
        let subjectMarkers = [
            "receipt", "invoice",
            "order confirmed", "order confirmation",
            "your order", "purchase confirmation",
            "thanks for your order", "thank you for your order",
        ]
        if subjectMarkers.contains(where: subject.contains) {
            score += 0.25
            reasons.append("subject-marker")
        }

        // 4b. "order" + a confirmation/shipment verb in the subject — catches the
        // common `Order #98765 confirmed` shape that the literal markers above
        // miss because of the interpolated id.
        let orderVerbs = ["confirmed", "confirmation", "received", "placed", "processed"]
        if subject.contains("order") && orderVerbs.contains(where: subject.contains) {
            score += 0.2
            reasons.append("subject:order-verb")
        }

        // 5. Order-number patterns.
        let hasOrderNumberPattern =
            combined.range(of: #"#[a-z0-9][a-z0-9\-]{3,}"#, options: .regularExpression) != nil
            || combined.contains("order #")
            || combined.contains("order id")
            || combined.contains("order number")
            || combined.contains("confirmation #")
            || combined.contains("confirmation number")
        if hasOrderNumberPattern {
            score += 0.2
            reasons.append("order-number")
        }

        // 6. Money pattern — currency symbol + digits, or "total"/"subtotal".
        let hasMoney =
            combined.range(of: #"[$£€¥][0-9]+(\.[0-9]{2})?"#, options: .regularExpression) != nil
            || combined.contains("total:")
            || combined.contains("subtotal:")
        if hasMoney {
            score += 0.1
            reasons.append("money")
        }

        // 7. Shipping markers (shipping notifications are transactional too).
        let shippingMarkers = [
            "shipped", "out for delivery", "tracking number",
            "your package", "delivery update", "on its way",
        ]
        if shippingMarkers.contains(where: body.contains) {
            score += 0.1
            reasons.append("shipping")
        }

        // 8. Attachment (often invoice PDF).
        if signals.hasAttachments {
            score += 0.05
            reasons.append("attachment")
        }

        // 9. Marketing/promo penalty — caps at -0.3 regardless of hit count.
        let promoMarkers = [
            "% off", "sale ends", "flash sale", "limited time",
            "deal of the day", "exclusive offer", "shop now",
            "ends tonight", "last chance", "unlock", "free shipping with code",
        ]
        let promoHits = promoMarkers.filter(combined.contains).count
        if promoHits > 0 {
            let penalty = min(0.3, Double(promoHits) * 0.12)
            score -= penalty
            reasons.append("promo:-\(String(format: "%.2f", penalty))")
        }

        let clamped = min(1.0, max(0.0, score))
        return CandidateScore(
            likelyPurchase: clamped >= threshold,
            score: clamped,
            reasons: reasons
        )
    }
}
