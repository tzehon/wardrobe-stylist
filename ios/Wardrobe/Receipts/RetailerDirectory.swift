import Foundation

/// Hand-curated set of sender signals used by `CandidateClassifier` to bump the
/// score on emails that *look* transactional. Deliberately conservative — we'd
/// rather miss a candidate (Tier 0 false negative) than send a marketing email
/// to Tier 2 (false positive costs money). The catalog grows as we observe the
/// user's real inbox.
enum RetailerDirectory {

    /// Exact-match domains, lowercased. Subdomains also match — `us.everlane.com`
    /// satisfies `everlane.com`.
    static let knownDomains: Set<String> = [
        // generalist marketplaces / platforms
        "amazon.com", "amazon.co.uk", "amazon.de", "amazon.fr", "amazon.ca",
        "etsy.com", "shopify.com", "shopifyemail.com",
        // fashion DTC + chains
        "everlane.com", "uniqlo.com", "zara.com", "hm.com",
        "gap.com", "bananarepublic.com", "jcrew.com", "madewell.com",
        "asos.com", "stitchfix.com", "rentrunway.com",
        // premium / luxury multi-brand
        "nordstrom.com", "neimanmarcus.com", "saksfifthavenue.com",
        "ssense.com", "mrporter.com", "net-a-porter.com", "matchesfashion.com",
        // jewelry
        "mejuri.com", "monicavinader.com", "missoma.com",
        // bags
        "mansurgavriel.com", "telfar.net", "polene-paris.com", "byfar.com",
        // footwear / athleisure
        "nike.com", "adidas.com", "newbalance.com", "allbirds.com", "lululemon.com",
        // fast fashion
        "shein.com", "fashionnova.com",
    ]

    /// Local-parts (text before the `@`) that strongly suggest a transactional
    /// rather than marketing sender — even from unknown domains.
    static let transactionalLocalParts: Set<String> = [
        "orders", "order",
        "receipts", "receipt",
        "billing", "transactional",
        "notify", "notifications",
        "noreply", "no-reply", "donotreply", "do-not-reply",
        "shipping", "support",
    ]

    /// True if `domain` is on the known list, either exactly or as a subdomain.
    static func isKnownRetailer(domain: String) -> Bool {
        let d = domain.lowercased()
        if knownDomains.contains(d) { return true }
        return knownDomains.contains { d.hasSuffix("." + $0) }
    }

    /// True if `localPart` (the bit before `@`) matches a transactional pattern.
    static func isTransactionalLocalPart(_ localPart: String) -> Bool {
        transactionalLocalParts.contains(localPart.lowercased())
    }
}
