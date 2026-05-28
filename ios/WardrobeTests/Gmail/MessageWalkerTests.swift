import Foundation
import Testing

@testable import Wardrobe

struct MessageWalkerTests {
    private let decoder = JSONDecoder()

    private func sampleMessage() throws -> GmailMessage {
        try decoder.decode(
            GmailMessage.self,
            from: Data(GmailFixtures.messageMultipartJSON.utf8)
        )
    }

    @Test func leafPartsFlattensNestedTree() throws {
        let msg = try sampleMessage()
        let leaves = MessageWalker.leafParts(of: msg.payload!)
        // text/plain + text/html + application/pdf
        #expect(leaves.count == 3)
        let mimes = leaves.map { $0.mimeType ?? "" }
        #expect(mimes.contains("text/plain"))
        #expect(mimes.contains("text/html"))
        #expect(mimes.contains("application/pdf"))
    }

    @Test func bestTextPrefersPlainOverHtml() throws {
        let msg = try sampleMessage()
        let result = try #require(MessageWalker.bestText(of: msg))
        #expect(result.mimeType == "text/plain")
        #expect(result.text == "Hello, world!")
    }

    @Test func attachmentPartsReturnsOnlyAttachments() throws {
        let msg = try sampleMessage()
        let attachments = MessageWalker.attachmentParts(of: msg)
        #expect(attachments.count == 1)
        #expect(attachments.first?.filename == "receipt.pdf")
        #expect(attachments.first?.body?.attachmentId == "ATT_1")
    }

    @Test func headerLookupIsCaseInsensitive() throws {
        let msg = try sampleMessage()
        let payload = try #require(msg.payload)
        #expect(MessageWalker.headerValue("from", in: payload) == "orders@retailer.com")
        #expect(MessageWalker.headerValue("SUBJECT", in: payload) == "Order #98765 confirmed")
        #expect(MessageWalker.headerValue("X-Missing", in: payload) == nil)
    }
}
