import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct SmokeTests {
    @Test func canInsertAndFetchItemInMemory() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Outfit.self, WearLog.self,
            configurations: config
        )
        let context = container.mainContext

        let item = Item(name: "Navy linen shirt", category: "top", source: .manual)
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Item>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Navy linen shirt")
        #expect(fetched.first?.category == "top")
    }

    @Test func gmailEndpointBuildsExpectedURL() {
        let endpoint = GmailReadEndpoint.listMessages(
            query: "subject:receipt", includeSpamTrash: true, pageToken: nil
        )
        let url = endpoint.url
        #expect(url.absoluteString.hasPrefix(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages"
        ))
        #expect(url.absoluteString.contains("includeSpamTrash=true"))
    }
}
