import Foundation
import Testing

@testable import Wardrobe

struct ReceiptPayloadBuilderTests {
    @Test func jsonLDProductsWinWithoutExposingPlainBodyOrMessageMetadata() throws {
        let html = """
            <html><body>
              <script type="application/ld+json">
              {
                "@type": "Product",
                "name": "Linen Camp Shirt",
                "brand": {"@type": "Brand", "name": "Everlane"},
                "offers": {
                  "@type": "Offer",
                  "price": "88.00",
                  "priceCurrency": "USD"
                },
                "image": "https://cdn.example.com/orders/ABC12345/taylor%40example.com/shirt.jpg?customer=taylor%40example.com"
              }
              </script>
              <p>Ship to Taylor Example, 123 Orchard Road, Singapore 238888</p>
            </body></html>
            """
        let data = try PipelineFixtures.multipartMessageJSON(
            id: "gmail-private-id-99",
            sender: #""Everlane Orders" <orders@everlane.com>"#,
            subject: "Order #ABC12345 for taylor@example.com",
            plainBody: """
                Taylor Example
                123 Orchard Road
                Singapore 238888
                Phone +65 9123 4567
                Visa ending in 4242
                """,
            htmlBody: html,
            labels: ["INBOX", "CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))

        #expect(payload.source == .structuredProducts)
        #expect(payload.senderDomain == "everlane.com")
        #expect(payload.subject == "Order [redacted] for [redacted]")
        #expect(payload.snippet.count <= ReceiptPayloadBuilder.maximumSnippetCharacters)
        #expect(payload.snippet.contains("Linen Camp Shirt"))
        #expect(payload.snippet.contains("Everlane"))
        #expect(payload.snippet.contains("88"))
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(payload.snippet.utf8)) as? [String: Any]
        )
        let products = try #require(object["products"] as? [[String: Any]])
        #expect(products.count == 1)
        #expect(products.first?["image_url"] == nil)
        #expect(!payload.snippet.contains("cdn.example.com"))
        #expect(!payload.snippet.contains("customer="))
        #expect(!payload.snippet.contains("gmail-private-id-99"))
        #expect(!payload.snippet.contains("taylor@example.com"))
        #expect(!payload.snippet.contains("123 Orchard"))
        #expect(!payload.snippet.contains("238888"))
        #expect(!payload.snippet.contains("9123"))
        #expect(!payload.snippet.contains("4242"))
        #expect(!payload.snippet.contains("ABC12345"))
    }

    @Test func oversizedStructuredProductsRemainCompleteValidBoundedJSON() throws {
        let products = (0..<12).map { index in
            let longPath = String(repeating: "a", count: 450) + "\(index)"
            return """
                {
                  "@type": "Product",
                  "name": "Product \(index) Premium Cotton Overshirt",
                  "brand": {"name": "Brand \(index)"},
                  "offers": {"price": "\(100 + index).00", "priceCurrency": "USD"},
                  "image": "https://cdn.example.com/\(longPath).jpg"
                }
                """
        }.joined(separator: ",")
        let html = """
            <script type="application/ld+json">
            {"@graph":[\(products)]}
            </script>
            """
        let data = try PipelineFixtures.multipartMessageJSON(
            id: "large-jsonld",
            sender: "orders@example.com",
            subject: "Your order",
            plainBody: "Raw receipt fallback must not win",
            htmlBody: html,
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(payload.snippet.utf8)) as? [String: Any]
        )
        let emittedProducts = try #require(object["products"] as? [[String: Any]])

        #expect(payload.source == .structuredProducts)
        #expect(payload.snippet.count <= ReceiptPayloadBuilder.maximumSnippetCharacters)
        #expect(!emittedProducts.isEmpty)
        #expect(emittedProducts.count <= 12)
        #expect(emittedProducts.allSatisfy { $0["name"] != nil })
        #expect(emittedProducts.allSatisfy { $0["image_url"] == nil })
    }

    @Test func fallbackKeepsOnlyProductLinesAndRedactsPIIAndIdentifiers() throws {
        let body = """
            1x Classic Oxford Shirt - White - $78.00
            Size: M
            Order Number: ABC-123456
            Contact: taylor@example.com or +65 9123 4567
            Card ending in 4242

            Shipping Address

            Taylor Example
            123 Orchard Road
            Singapore 238888
            Shipping fee $8.00

            Items:
            1x Merino Sweater - Navy - $120.00
            Unsubscribe from these emails
            Footer total $206.00
            """
        let data = try PipelineFixtures.messageJSON(
            id: "private-gmail-id",
            sender: "Taylor <orders@shop.example>",
            subject: "Order #ABC-123456 to taylor@example.com",
            body: body,
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))

        #expect(payload.source == .productExcerpt)
        #expect(payload.senderDomain == "shop.example")
        #expect(payload.subject == "Order [redacted] to [redacted]")
        #expect(payload.snippet.contains("Classic Oxford Shirt"))
        #expect(payload.snippet.contains("Size: M"))
        #expect(payload.snippet.contains("Merino Sweater"))
        #expect(!payload.snippet.contains("Shipping fee"))
        #expect(!payload.snippet.contains("Footer total"))
        #expect(!payload.snippet.contains("ABC-123456"))
        #expect(!payload.snippet.contains("taylor@example.com"))
        #expect(!payload.snippet.contains("9123"))
        #expect(!payload.snippet.contains("4242"))
        #expect(!payload.snippet.contains("123 Orchard"))
        #expect(!payload.snippet.contains("238888"))
        #expect(!payload.snippet.contains("private-gmail-id"))
        #expect(payload.snippet.count <= ReceiptPayloadBuilder.maximumSnippetCharacters)
    }

    @Test func noStructuredProductOrProductRelevantTextProducesNoPayload() throws {
        let data = try PipelineFixtures.messageJSON(
            id: "empty",
            sender: "not a mailbox",
            subject: "Hello",
            body: "Thanks for getting in touch. We will reply soon."
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        #expect(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ) == nil)
    }

    @Test func billingAndPaymentBlocksStayExcludedAcrossBlankLines() throws {
        let data = try PipelineFixtures.messageJSON(
            id: "billing-block",
            sender: "orders@shop.example",
            subject: "Your order is confirmed",
            body: """
                Billing Address

                Taylor Example
                55 Market Street
                San Francisco CA 94105
                Payment details

                Mastercard ending in 4242
                Tax total $19.50

                Order Summary:
                1x Wool Coat - Camel - $320.00
                """,
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))

        #expect(payload.snippet == "1x Wool Coat - Camel - $320.00")
        #expect(!payload.snippet.contains("Tax total"))
        #expect(!payload.snippet.contains("55 Market"))
        #expect(!payload.snippet.contains("94105"))
        #expect(!payload.snippet.contains("4242"))
    }

    @Test func subjectRedactionRemovesWholeOrderInvoiceAndTrackingIdentifiers() throws {
        let identifiers = [
            "ABC-123456",
            "INV987654",
            "ZX-42-TRACK",
            "CONF-556677",
        ]
        let subject = """
            Order #ABC-123456 Invoice ID: INV987654 \
            Tracking no. ZX-42-TRACK Confirmation: CONF-556677
            """
        let data = try PipelineFixtures.messageJSON(
            id: "identifier-subject",
            sender: "orders@shop.example",
            subject: subject,
            body: "1x Wool Coat - $320.00",
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))
        let sanitized = try #require(payload.subject)

        for identifier in identifiers {
            #expect(!sanitized.localizedCaseInsensitiveContains(identifier))
            let fragments = identifier.split(separator: "-").map(String.init)
                .filter {
                    $0.count >= 3
                        && !["TRACK", "CONF"].contains($0.uppercased())
                }
            for fragment in fragments {
                #expect(!sanitized.localizedCaseInsensitiveContains(fragment))
            }
        }
        #expect(sanitized == "Order [redacted] Invoice [redacted] Tracking [redacted] Confirmation [redacted]")
    }

    @Test func subjectRedactionRemovesUnlabeledIdentifiersWithoutRedactingOrdinaryLabels() throws {
        let identifiers = ["ABC12345", "INV987654", "ZX42TRACK", "CONF556677"]
        let data = try PipelineFixtures.messageJSON(
            id: "unlabeled-identifier-subject",
            sender: "orders@shop.example",
            subject: "Order ABC12345 Invoice INV987654 Tracking ZX42TRACK Confirmation CONF556677 — Order Summary",
            body: "1x Wool Coat - $320.00",
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))
        let sanitized = try #require(payload.subject)

        for identifier in identifiers {
            #expect(!sanitized.localizedCaseInsensitiveContains(identifier))
        }
        #expect(
            sanitized
                == "Order [redacted] Invoice [redacted] Tracking [redacted] Confirmation [redacted] — Order Summary"
        )
    }

    @Test func fallbackRemovesCompleteTokenizedURLsAndKeepsProductText() throws {
        let data = try PipelineFixtures.messageJSON(
            id: "tokenized-links",
            sender: "orders@shop.example",
            subject: "Your Wool Coat order",
            body: """
                1x Wool Coat - Camel - $320.00 https://shop.example/orders/AB_12345/item?token=SECRET123&email=taylor%40example.com#private
                Product page: www.shop.example/customer/AB_12345?auth=PRIVATE456
                """,
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))

        #expect(payload.snippet.contains("1x Wool Coat - Camel - $320.00"))
        #expect(payload.snippet.contains("Product page:"))
        #expect(!payload.snippet.localizedCaseInsensitiveContains("https://"))
        #expect(!payload.snippet.localizedCaseInsensitiveContains("www."))
        #expect(!payload.snippet.localizedCaseInsensitiveContains("shop.example"))
        #expect(!payload.snippet.contains("/orders/"))
        #expect(!payload.snippet.contains("/customer/"))
        #expect(!payload.snippet.localizedCaseInsensitiveContains("token="))
        #expect(!payload.snippet.contains("SECRET123"))
        #expect(!payload.snippet.localizedCaseInsensitiveContains("auth="))
        #expect(!payload.snippet.contains("PRIVATE456"))
        #expect(!payload.snippet.contains("AB_12345"))
    }

    @Test func identifierRedactionHandlesSlashDotAndUnderscoreWithoutRedactingLabels() throws {
        let identifiers = ["AB_12345", "INV/2026/001", "TRK.2026.08"]
        let data = try PipelineFixtures.messageJSON(
            id: "separator-identifiers",
            sender: "orders@shop.example",
            subject: "Order AB_12345 Invoice INV/2026/001 Tracking TRK.2026.08 — Order Summary — Tracking updates",
            body: "Invoice INV/2026/001 for 1x Wool Coat - $320.00",
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))
        let sanitizedSubject = try #require(payload.subject)

        for identifier in identifiers {
            #expect(!sanitizedSubject.localizedCaseInsensitiveContains(identifier))
            #expect(!payload.snippet.localizedCaseInsensitiveContains(identifier))
        }
        #expect(
            sanitizedSubject
                == "Order [redacted] Invoice [redacted] Tracking [redacted] — Order Summary — Tracking updates"
        )
        #expect(payload.snippet == "Invoice [redacted] for 1x Wool Coat - $320.00")
    }

    @Test func fallbackRedactsPIIBeforeApplyingPerLineCharacterLimit() throws {
        let lead = "1x Wool Coat - $320.00 "
        let partialEmailAtOldBoundary = "taylor@exa"
        let paddingCount = 240 - lead.count - partialEmailAtOldBoundary.count
        let body = lead
            + String(repeating: "x", count: paddingCount)
            + "taylor@example.com"
        let data = try PipelineFixtures.messageJSON(
            id: "redaction-boundary",
            sender: "orders@shop.example",
            subject: "Your order is confirmed",
            body: body,
            labels: ["CATEGORY_PURCHASES"]
        )
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        let payload = try #require(ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: SignalsExtractor.makeSignals(from: message)
        ))

        #expect(payload.snippet.count <= 240)
        #expect(payload.snippet.contains("[redacted]"))
        #expect(!payload.snippet.contains("taylor"))
        #expect(!payload.snippet.contains("@exa"))
        #expect(!payload.snippet.contains("example.com"))
    }
}
