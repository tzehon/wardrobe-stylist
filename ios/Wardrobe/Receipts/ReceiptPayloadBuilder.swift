import Foundation

/// The privacy-minimised representation of a receipt that may cross the
/// device/backend boundary. It deliberately has no Gmail message identifier or
/// sender mailbox field; `ReceiptPipeline` adds the opaque source id only to the
/// HTTP compatibility envelope used by `/extract`.
struct ReceiptExtractionPayload: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case structuredProducts
        case productExcerpt
    }

    let senderDomain: String?
    let subject: String?
    let snippet: String
    let source: Source
}

/// Builds the smallest useful extraction payload from an already-fetched Gmail
/// message. JSON-LD products win over every textual representation, so a rich
/// HTML receipt never falls back to sending its address/payment/footer content.
enum ReceiptPayloadBuilder {
    static let maximumSnippetCharacters = 1_800

    private static let maximumSubjectCharacters = 160
    private static let maximumProductNameCharacters = 180
    private static let maximumBrandCharacters = 100
    private static let maximumProducts = 12
    private static let maximumExcerptLines = 18
    private static let maximumExcerptLineCharacters = 240

    static func makePayload(
        message: GmailMessage,
        signals: CandidateSignals
    ) -> ReceiptExtractionPayload? {
        let senderDomain = normalizedDomain(signals.senderDomain)
        let subject = sanitizedSubject(signals.subject)

        if let structured = structuredProductSnippet(from: message) {
            return ReceiptExtractionPayload(
                senderDomain: senderDomain,
                subject: subject,
                snippet: structured,
                source: .structuredProducts
            )
        }

        guard let excerpt = productRelevantExcerpt(from: signals.bodyText) else {
            return nil
        }
        return ReceiptExtractionPayload(
            senderDomain: senderDomain,
            subject: subject,
            snippet: excerpt,
            source: .productExcerpt
        )
    }

    // MARK: - Structured products

    private static func structuredProductSnippet(from message: GmailMessage) -> String? {
        guard let payload = message.payload else { return nil }
        let htmlLeaves = MessageWalker.leafParts(of: payload).filter {
            $0.mimeType?.lowercased().hasPrefix("text/html") == true
        }

        var products: [[String: Any]] = []
        for leaf in htmlLeaves {
            guard let encoded = leaf.body?.data,
                  let data = Base64URL.decode(encoded),
                  let html = String(data: data, encoding: .utf8) else {
                continue
            }
            for item in JSONLDExtractor.extract(fromHTML: html) {
                guard let name = sanitizedField(
                    item.name,
                    maximumCharacters: maximumProductNameCharacters
                ), containsLetter(name) else {
                    continue
                }

                var product: [String: Any] = ["name": name]
                if let brand = sanitizedField(
                    item.brand,
                    maximumCharacters: maximumBrandCharacters
                ) {
                    product["brand"] = brand
                }
                if let price = item.price, price.isFinite, price >= 0 {
                    product["price"] = price
                }
                if let currency = normalizedCurrency(item.currency) {
                    product["currency"] = currency
                }
                products.append(product)
                if products.count >= maximumProducts { break }
            }
            if products.count >= maximumProducts { break }
        }

        guard !products.isEmpty else { return nil }

        // Never truncate JSON. Image URLs are deliberately excluded: even after
        // removing query parameters, retailer CDN paths can contain customer or
        // order identifiers. Drop whole trailing products until the remaining
        // complete serialization fits the bounded transport field.
        while !products.isEmpty {
            if let json = encodeStructuredProducts(products),
               json.count <= maximumSnippetCharacters {
                return json
            }
            products.removeLast()
        }
        return nil
    }

    private static func encodeStructuredProducts(_ products: [[String: Any]]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: [
                "format": "schema.org-products-v1",
                "products": products,
            ],
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func normalizedCurrency(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              value.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    // MARK: - Text fallback

    private static func productRelevantExcerpt(from body: String) -> String? {
        var excerpt: [String] = []
        var droppingSensitiveSection = false

        for rawLine in body.components(separatedBy: .newlines) {
            let line = normalizedWhitespace(rawLine)
            if line.isEmpty { continue }

            if isFooterBoundary(line) { break }
            if isSensitiveSectionHeader(line) {
                droppingSensitiveSection = true
                continue
            }
            if droppingSensitiveSection {
                guard isProductSectionHeader(line) else { continue }
                droppingSensitiveSection = false
                continue
            }
            if isSensitiveMetadataLine(line) { continue }
            guard isProductRelevant(line) else { continue }

            guard let sanitized = sanitizedField(
                line,
                maximumCharacters: maximumExcerptLineCharacters
            ), !sanitized.isEmpty else {
                continue
            }
            excerpt.append(sanitized)
            if excerpt.count >= maximumExcerptLines { break }
        }

        guard !excerpt.isEmpty else { return nil }
        let result = excerpt.joined(separator: "\n")
        return String(result.prefix(maximumSnippetCharacters))
    }

    private static func isProductRelevant(_ line: String) -> Bool {
        let patterns = [
            #"(?i)(?:[$£€¥] ?\d|\b\d+(?:\.\d{2})?\s?(?:USD|GBP|EUR|SGD|AUD|CAD|JPY)\b)"#,
            #"(?i)\b(?:qty|quantity|item|product|size|colour|color|material|subtotal|total|purchased)\b"#,
            #"(?i)\b(?:shirt|tee|t-shirt|top|blouse|sweater|jumper|hoodie|jacket|coat|dress|skirt|jeans|trousers|pants|shorts|shoe|sneaker|boot|sandal|bag|belt|hat|scarf|sock|underwear|bra|watch|jewellery|jewelry)\b"#,
            #"(?i)^\s*\d+\s*[x×]\s*"#,
        ]
        return patterns.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    private static func isSensitiveSectionHeader(_ line: String) -> Bool {
        line.range(
            of: #"(?i)^(?:shipping|billing|delivery|payment)\s+(?:address|details|information)|^(?:ship|deliver|bill)\s+to\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func isSensitiveMetadataLine(_ line: String) -> Bool {
        line.range(
            of: #"(?i)^(?:email|e-mail|phone|telephone|mobile|card|payment method|order (?:number|no\.?|id)|confirmation (?:number|no\.?|id)|tracking (?:number|no\.?|id)|invoice (?:number|no\.?|id)|address)\s*[:#-]"#,
            options: .regularExpression
        ) != nil
    }

    private static func isProductSectionHeader(_ line: String) -> Bool {
        line.range(
            of: #"(?i)^(?:items?|products?|order summary|purchased items?|what you (?:bought|ordered))\s*:?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isFooterBoundary(_ line: String) -> Bool {
        line.range(
            of: #"(?i)\b(?:unsubscribe|manage (?:your )?preferences|view (?:this email )?in (?:your )?browser|privacy policy|terms (?:and|&) conditions|all rights reserved|customer service)\b"#,
            options: .regularExpression
        ) != nil
    }

    // MARK: - PII sanitisation

    private static func sanitizedSubject(_ raw: String) -> String? {
        sanitizedField(raw, maximumCharacters: maximumSubjectCharacters)
    }

    private static func sanitizedField(
        _ raw: String?,
        maximumCharacters: Int
    ) -> String? {
        guard var value = raw else { return nil }
        value = value.unicodeScalars.map {
            CharacterSet.controlCharacters.contains($0) ? " " : String($0)
        }.joined()
        value = redactPII(in: value)
        value = normalizedWhitespace(value)
        value = value.replacingOccurrences(
            of: #"(?:\[redacted\]\s*){2,}"#,
            with: "[redacted] ",
            options: .regularExpression
        )
        value = String(value.prefix(maximumCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func redactPII(in input: String) -> String {
        let replacements = [
            // URLs can carry customer, order, authentication, and tracking data
            // in any path/query/fragment component. Product extraction never
            // needs the link itself, so remove the complete token before more
            // specific patterns inspect its contents.
            (
                #"(?i)\b(?:https?://|www\.)[^\s<>\"']+"#,
                "[redacted]"
            ),
            // Email addresses.
            (
                #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
                "[redacted]"
            ),
            // Explicit order/confirmation/tracking/invoice identifiers. Keep
            // the label because it is useful receipt context, but never its id.
            (
                #"(?i)\b(order|confirmation|invoice|receipt|tracking|reference)\s*(?:(?:number|no\.?|id)\s*[:#-]?|[#:-])\s*(?=[A-Z0-9._/-]{4,}\b)(?=[A-Z0-9._/-]*\d)[A-Z0-9](?:[A-Z0-9._/-]{2,}[A-Z0-9])\b"#,
                "$1 [redacted]"
            ),
            // Many retailers omit a separator entirely (for example,
            // "Order ABC12345 confirmed"). Require an identifier-looking token
            // with a digit so ordinary phrases such as "Order Summary" survive.
            (
                #"(?i)\b(order|confirmation|invoice|receipt|tracking|reference)\s+(?=[A-Z0-9._/-]{4,}\b)(?=[A-Z0-9._/-]*\d)[A-Z0-9](?:[A-Z0-9._/-]{2,}[A-Z0-9])\b"#,
                "$1 [redacted]"
            ),
            // Full card numbers and labelled last-four fragments.
            (#"(?<!\d)(?:\d[ -]?){13,19}(?!\d)"#, "[redacted]"),
            (
                #"(?i)\b(?:card|visa|mastercard|amex|ending(?:\s+in)?|last\s*4)\s*[:#-]?\s*(?:[\u2022*xX-]*\s*)?\d{4}\b"#,
                "[redacted]"
            ),
            // International and domestic phone-number-like sequences.
            (#"(?<!\d)(?:\+?\d[\d ()-]{7,}\d)(?!\d)"#, "[redacted]"),
            // Street addresses.
            (
                #"(?i)\b\d{1,6}\s+[A-Z0-9.' -]{2,48}\s(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|boulevard|blvd|way|court|ct|place|pl|terrace|highway|hwy)\b[^,\n]*"#,
                "[redacted]"
            ),
            // Common postal-code forms (US, Singapore, Canada, UK).
            (
                #"(?i)\b(?:\d{5}(?:-\d{4})?|\d{6}|[A-Z]\d[A-Z][ -]?\d[A-Z]\d|[A-Z]{1,2}\d[A-Z\d]?[ -]?\d[A-Z]{2})\b"#,
                "[redacted]"
            ),
            (
                #"(?i)#(?=[A-Z0-9._/-]{4,}\b)(?=[A-Z0-9._/-]*\d)[A-Z0-9](?:[A-Z0-9._/-]{2,}[A-Z0-9])\b"#,
                "[redacted]"
            ),
        ]
        return replacements.reduce(input) { value, replacement in
            let (pattern, redactedValue) = replacement
            return value.replacingOccurrences(
                of: pattern,
                with: redactedValue,
                options: .regularExpression
            )
        }
    }

    private static func normalizedWhitespace(_ input: String) -> String {
        input.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedDomain(_ raw: String?) -> String? {
        guard let value = raw?.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ". \t\r\n")),
              !value.isEmpty,
              value.count <= 253,
              !value.contains("@") else {
            return nil
        }
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty
                      && label.count <= 63
                      && label.first != "-"
                      && label.last != "-"
                      && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
              }) else {
            return nil
        }
        return value
    }

    private static func containsLetter(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }
}
