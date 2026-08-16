import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct GmailProcessedStateStoreTests {
    private enum FixtureError: Error { case saveFailed }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
    }

    private func fixture() throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        container.mainContext.autosaveEnabled = false
        return Fixture(container: container, context: container.mainContext)
    }

    @Test func processedMessagesAreIdempotentAndIsolatedPerAccount() throws {
        let fixture = try fixture()
        let accountA = PrivacySubjectID.external("account-a")
        let accountB = PrivacySubjectID.external("account-b")
        let storeA = GmailProcessedStateStore(modelContext: fixture.context, subjectID: accountA)
        let storeB = GmailProcessedStateStore(modelContext: fixture.context, subjectID: accountB)

        let first = try storeA.markProcessed(
            messageID: "gmail-message-1",
            outcome: .imported,
            processedAt: Date(timeIntervalSince1970: 100),
            gmailHistoryID: "history-10"
        )
        let repeated = try storeA.markProcessed(
            messageID: "gmail-message-1",
            outcome: .notFashion,
            processedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(first.persistentModelID == repeated.persistentModelID)
        #expect(try storeA.hasProcessed(messageID: "gmail-message-1"))
        #expect(try !storeB.hasProcessed(messageID: "gmail-message-1"))
        #expect(try storeA.processedMessageIDs() == ["gmail-message-1"])
        #expect(try storeB.processedMessageIDs().isEmpty)

        let entry = try #require(fixture.context.fetch(FetchDescriptor<ProcessedGmailMessage>()).first)
        #expect(entry.outcomeRawValue == ProcessedGmailMessageOutcome.imported.rawValue)
        #expect(entry.gmailHistoryID == "history-10")
        #expect(!entry.scopedMessageKey.contains("gmail-message-1"))
        #expect(!entry.accountSubjectKey.contains("account-a"))
    }

    @Test func syncCursorsAreIndependentPerAccount() throws {
        let fixture = try fixture()
        let storeA = GmailProcessedStateStore(
            modelContext: fixture.context,
            subjectID: .external("account-a")
        )
        let storeB = GmailProcessedStateStore(
            modelContext: fixture.context,
            subjectID: .external("account-b")
        )
        let date = Date(timeIntervalSince1970: 500)

        try storeA.updateSyncState(
            historyID: "history-a",
            nextBackfillPageToken: "page-a",
            backfillCompletedAt: nil,
            lastSuccessfulSyncAt: date
        )
        try storeB.updateSyncState(
            historyID: "history-b",
            nextBackfillPageToken: nil,
            backfillCompletedAt: date,
            lastSuccessfulSyncAt: date
        )

        #expect(try storeA.syncState()?.historyID == "history-a")
        #expect(try storeA.syncState()?.nextBackfillPageToken == "page-a")
        #expect(try storeB.syncState()?.historyID == "history-b")
        #expect(try storeB.syncState()?.backfillCompletedAt == date)
        #expect(try fixture.context.fetch(FetchDescriptor<GmailSyncState>()).count == 2)
    }

    @Test func failedLedgerSaveRollsBackAndDoesNotMarkTheMessage() throws {
        let fixture = try fixture()
        let subject = PrivacySubjectID.external("account-a")
        let failing = GmailProcessedStateStore(
            modelContext: fixture.context,
            subjectID: subject,
            save: { _ in throw FixtureError.saveFailed }
        )

        #expect(throws: GmailProcessedStateError.self) {
            try failing.markProcessed(messageID: "message", outcome: .notPurchase)
        }

        let verification = ModelContext(fixture.container)
        #expect(try verification.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
        #expect(!fixture.context.hasChanges)
    }

    @Test func failedAtomicCommitRollsBackCatalogChangesWithLedger() throws {
        let fixture = try fixture()
        let failing = GmailProcessedStateStore(
            modelContext: fixture.context,
            subjectID: .external("account-a"),
            save: { _ in throw FixtureError.saveFailed }
        )

        #expect(throws: GmailProcessedStateError.self) {
            try failing.commitProcessed(
                messageID: "message",
                outcome: .imported
            ) {
                fixture.context.insert(Item(
                    name: "Transactional Shirt",
                    category: "top",
                    source: .email,
                    sourceMsgId: "message",
                    accountSubjectKey: WardrobeAccountScope.external(
                        .external("account-a")
                    ).rawValue
                ))
            }
        }

        let verification = ModelContext(fixture.container)
        #expect(try verification.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
        #expect(!fixture.context.hasChanges)
    }
}
