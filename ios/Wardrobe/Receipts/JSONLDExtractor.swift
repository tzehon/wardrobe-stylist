import Foundation

/// One product extracted deterministically from schema.org JSON-LD embedded in
/// an email's HTML. Tier 1 — no network, no LLM, free. All commercial fields
/// are optional because retailer emails vary widely in what they include.
struct SchemaOrgItem: Equatable, Sendable {
    var name: String
    var brand: String?
    var price: Double?
    var currency: String?
    var imageURL: String?
}

/// Extracts `SchemaOrgItem`s from email HTML by locating
/// `<script type="application/ld+json">` blocks, JSON-parsing them, and walking
/// the result for nodes that look like `Product`s (or `Order`/`OrderItem`
/// wrappers that contain Products). Tolerant of the shape variations real
/// retailers ship.
enum JSONLDExtractor {

    static func extract(fromHTML html: String) -> [SchemaOrgItem] {
        var items: [SchemaOrgItem] = []
        for jsonString in findBlocks(in: html) {
            guard let data = jsonString.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data, options: []) else {
                continue
            }
            collect(node: root, parentOffer: nil, into: &items)
        }
        return dedupe(items)
    }

    // MARK: - Block discovery

    /// Returns the raw JSON strings inside every `<script type="application/ld+json">`
    /// block (case-insensitive on `type`, tolerant of single or double quotes).
    private static func findBlocks(in html: String) -> [String] {
        let pattern =
            #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive]
        ) else { return [] }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        var results: [String] = []
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let m = match, m.numberOfRanges > 1 else { return }
            let captured = ns.substring(with: m.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !captured.isEmpty { results.append(captured) }
        }
        return results
    }

    // MARK: - Tree walk

    /// Walks the JSON-LD tree, emitting one `SchemaOrgItem` per Product-like
    /// node. The nearest Offer/Price found while descending acts as the
    /// fallback price for items further down (handles the Order → acceptedOffer
    /// → itemOffered shape, where the price is on the Offer, not the Product).
    private static func collect(
        node: Any,
        parentOffer: (price: Double, currency: String?)?,
        into items: inout [SchemaOrgItem]
    ) {
        if let array = node as? [Any] {
            for child in array {
                collect(node: child, parentOffer: parentOffer, into: &items)
            }
            return
        }
        guard let dict = node as? [String: Any] else { return }

        // The Offer/Price closest to this node wins for any Products nested below.
        let nodeOffer = extractOffer(from: dict) ?? parentOffer

        if isProduct(dict), let name = string(dict["name"]) {
            items.append(SchemaOrgItem(
                name: name,
                brand: extractBrand(dict["brand"]),
                price: nodeOffer?.price,
                currency: nodeOffer?.currency,
                imageURL: extractImage(dict["image"])
            ))
        }

        // Recurse into every value — handles @graph wrappers, acceptedOffer
        // arrays, OrderItem.orderedItem, etc., without needing to special-case
        // each schema.org key.
        for (_, value) in dict {
            collect(node: value, parentOffer: nodeOffer, into: &items)
        }
    }

    private static func isProduct(_ dict: [String: Any]) -> Bool {
        let types = stringList(dict["@type"])
        return types.contains("Product")
            || types.contains("ProductModel")
            || types.contains("IndividualProduct")
    }

    // MARK: - Field extraction

    /// Looks for a price in (a) the node itself, (b) `priceSpecification`,
    /// (c) `offers` (object or first array element, with its own
    /// `priceSpecification` fallback). Returns nil if nothing parseable.
    private static func extractOffer(
        from dict: [String: Any]
    ) -> (price: Double, currency: String?)? {
        if let p = number(dict["price"]) {
            return (p, string(dict["priceCurrency"]))
        }
        if let spec = dict["priceSpecification"] as? [String: Any],
           let p = number(spec["price"]) {
            return (p, string(spec["priceCurrency"]))
        }
        if let offerDict = firstDict(dict["offers"]) {
            if let p = number(offerDict["price"]) {
                return (p, string(offerDict["priceCurrency"]))
            }
            if let spec = offerDict["priceSpecification"] as? [String: Any],
               let p = number(spec["price"]) {
                return (p, string(spec["priceCurrency"]))
            }
        }
        return nil
    }

    private static func extractBrand(_ raw: Any?) -> String? {
        if let s = string(raw) { return s }
        if let dict = raw as? [String: Any], let name = string(dict["name"]) { return name }
        return nil
    }

    private static func extractImage(_ raw: Any?) -> String? {
        if let s = string(raw) { return s }
        if let dict = raw as? [String: Any], let url = string(dict["url"]) { return url }
        if let arr = raw as? [Any], let first = arr.first { return extractImage(first) }
        return nil
    }

    // MARK: - Primitive coercion

    private static func string(_ raw: Any?) -> String? {
        guard let s = raw as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private static func stringList(_ raw: Any?) -> [String] {
        if let s = raw as? String { return [s] }
        if let arr = raw as? [String] { return arr }
        if let arr = raw as? [Any] { return arr.compactMap { $0 as? String } }
        return []
    }

    /// Accepts numbers, ints, and strings (with currency symbols + commas stripped).
    private static func number(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let s = raw as? String {
            let cleaned = s.replacingOccurrences(
                of: "[^0-9.\\-]",
                with: "",
                options: .regularExpression
            )
            return cleaned.isEmpty ? nil : Double(cleaned)
        }
        return nil
    }

    private static func firstDict(_ raw: Any?) -> [String: Any]? {
        if let dict = raw as? [String: Any] { return dict }
        if let arr = raw as? [Any] { return arr.compactMap { $0 as? [String: Any] }.first }
        return nil
    }

    // MARK: - Dedupe

    /// Collapses duplicates on `(name, brand)` while preserving discovery order.
    /// Real Shopify emails sometimes emit the same Product twice across the
    /// nested Order + standalone Product blocks.
    private static func dedupe(_ items: [SchemaOrgItem]) -> [SchemaOrgItem] {
        var seen = Set<String>()
        var out: [SchemaOrgItem] = []
        for item in items {
            let key = "\(item.name.lowercased())|\(item.brand?.lowercased() ?? "")"
            if seen.insert(key).inserted {
                out.append(item)
            }
        }
        return out
    }
}
