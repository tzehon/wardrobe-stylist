import Foundation
import Testing

@testable import Wardrobe

struct GmailModelsTests {
    private let decoder = JSONDecoder()

    @Test func decodesProfile() throws {
        let profile = try decoder.decode(
            GmailProfile.self,
            from: Data(GmailFixtures.profileJSON.utf8)
        )
        #expect(profile.emailAddress == "user@example.com")
        #expect(profile.messagesTotal == 12345)
        #expect(profile.historyId == "987654")
    }

    @Test func decodesMessageListWithPageToken() throws {
        let list = try decoder.decode(
            GmailMessageList.self,
            from: Data(GmailFixtures.messageListPage1JSON.utf8)
        )
        #expect(list.nextPageToken == "PT_2")
        #expect(list.messages?.count == 2)
        #expect(list.messages?.first?.id == "m1")
    }

    @Test func decodesMessageListWithoutPageToken() throws {
        let list = try decoder.decode(
            GmailMessageList.self,
            from: Data(GmailFixtures.messageListPage2JSON.utf8)
        )
        #expect(list.nextPageToken == nil)
        #expect(list.messages?.count == 1)
    }

    @Test func decodesMultipartMessage() throws {
        let msg = try decoder.decode(
            GmailMessage.self,
            from: Data(GmailFixtures.messageMultipartJSON.utf8)
        )
        #expect(msg.id == "m1")
        #expect(msg.labelIds == ["INBOX", "CATEGORY_PROMOTIONS"])
        #expect(msg.payload?.mimeType == "multipart/mixed")
        #expect(msg.payload?.parts?.count == 2)
        // Header round-trip
        #expect(MessageWalker.headerValue("Subject", in: msg.payload!) == "Order #98765 confirmed")
    }

    @Test func decodesAttachment() throws {
        let att = try decoder.decode(
            GmailAttachment.self,
            from: Data(GmailFixtures.attachmentJSON.utf8)
        )
        #expect(att.attachmentId == "ATT_1")
        #expect(att.size == 13)
        let bytes = try #require(Base64URL.decode(att.data))
        #expect(String(data: bytes, encoding: .utf8) == "Hello, world!")
    }

    @Test func decodesHistory() throws {
        let history = try decoder.decode(
            GmailHistory.self,
            from: Data(GmailFixtures.historyJSON.utf8)
        )
        #expect(history.historyId == "101")
        #expect(history.history?.first?.messagesAdded?.first?.message.id == "mx")
    }
}
