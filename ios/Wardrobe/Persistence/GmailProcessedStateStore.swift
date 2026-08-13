import CryptoKit
import Foundation
import SwiftData

struct GmailProcessedStateError: Error, Equatable, LocalizedError, Sendable {
    let diagnostic: String

    var errorDescription: String? {
        "Couldn’t update receipt sync history."
    }

    var recoverySuggestion: String? {
        "No sync checkpoint was advanced. Please try the import again."
    }
}

/// Transaction boundary for one account's processed-message ledger and Gmail
/// cursors. It is intentionally independent of receipt payload construction so
/// APP-008 can adopt it without changing the HTTP contract.
@MainActor
final class GmailProcessedStateStore {
    typealias Save = @MainActor (ModelContext) throws -> Void

    private let modelContext: ModelContext
    private let accountScope: WardrobeAccountScope
    private let save: Save

    init(
        modelContext: ModelContext,
        subjectID: PrivacySubjectID,
        save: @escaping Save = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.accountScope = .external(subjectID)
        self.save = save
    }

    func hasProcessed(messageID: String) throws -> Bool {
        let key = Self.scopedMessageKey(accountScope: accountScope, messageID: messageID)
        let descriptor = FetchDescriptor<ProcessedGmailMessage>(
            predicate: #Predicate { $0.scopedMessageKey == key }
        )
        return try modelContext.fetchCount(descriptor) > 0
    }

    func processedMessageIDs() throws -> Set<String> {
        let accountKey = accountScope.rawValue
        let descriptor = FetchDescriptor<ProcessedGmailMessage>(
            predicate: #Predicate { $0.accountSubjectKey == accountKey }
        )
        return Set(try modelContext.fetch(descriptor).map(\.gmailMessageID))
    }

    @discardableResult
    func markProcessed(
        messageID: String,
        outcome: ProcessedGmailMessageOutcome,
        processedAt: Date = .now,
        gmailHistoryID: String? = nil
    ) throws -> ProcessedGmailMessage {
        let key = Self.scopedMessageKey(accountScope: accountScope, messageID: messageID)
        if let existing = try existingMessage(scopedKey: key) {
            return existing
        }
        return try transaction {
            let entry = ProcessedGmailMessage(
                scopedMessageKey: key,
                accountSubjectKey: accountScope.rawValue,
                gmailMessageID: messageID,
                processedAt: processedAt,
                outcome: outcome,
                gmailHistoryID: gmailHistoryID
            )
            modelContext.insert(entry)
            return entry
        }
    }

    func syncState() throws -> GmailSyncState? {
        let accountKey = accountScope.rawValue
        var descriptor = FetchDescriptor<GmailSyncState>(
            predicate: #Predicate { $0.accountSubjectKey == accountKey }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func updateSyncState(
        historyID: String?,
        nextBackfillPageToken: String?,
        backfillCompletedAt: Date?,
        lastSuccessfulSyncAt: Date?
    ) throws -> GmailSyncState {
        let existing = try syncState()
        return try transaction {
            let state: GmailSyncState
            if let existing {
                state = existing
            } else {
                state = GmailSyncState(accountSubjectKey: accountScope.rawValue)
                modelContext.insert(state)
            }
            state.historyID = historyID
            state.nextBackfillPageToken = nextBackfillPageToken
            state.backfillCompletedAt = backfillCompletedAt
            state.lastSuccessfulSyncAt = lastSuccessfulSyncAt
            return state
        }
    }

    private func existingMessage(scopedKey: String) throws -> ProcessedGmailMessage? {
        var descriptor = FetchDescriptor<ProcessedGmailMessage>(
            predicate: #Predicate { $0.scopedMessageKey == scopedKey }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func transaction<Result>(_ mutation: () throws -> Result) throws -> Result {
        guard !modelContext.hasChanges else {
            throw GmailProcessedStateError(diagnostic: "Model context has pending changes")
        }
        do {
            let result = try mutation()
            try save(modelContext)
            return result
        } catch let error as GmailProcessedStateError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw GmailProcessedStateError(diagnostic: String(describing: error))
        }
    }

    private static func scopedMessageKey(
        accountScope: WardrobeAccountScope,
        messageID: String
    ) -> String {
        let input = Data("gmail-message:v1:\(accountScope.rawValue):\(messageID)".utf8)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
