import Foundation
import SwiftData

extension WardrobeSchemaV2 {
    /// One cursor row per account. `nextBackfillPageToken` resumes an initial
    /// paged import; `historyID` resumes Gmail's incremental history feed after
    /// a completed backfill.
    @Model
    final class GmailSyncState {
        @Attribute(.unique) var accountSubjectKey: String
        var historyID: String?
        var nextBackfillPageToken: String?
        var backfillCompletedAt: Date?
        var lastSuccessfulSyncAt: Date?

        init(
            accountSubjectKey: String,
            historyID: String? = nil,
            nextBackfillPageToken: String? = nil,
            backfillCompletedAt: Date? = nil,
            lastSuccessfulSyncAt: Date? = nil
        ) {
            self.accountSubjectKey = accountSubjectKey
            self.historyID = historyID
            self.nextBackfillPageToken = nextBackfillPageToken
            self.backfillCompletedAt = backfillCompletedAt
            self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        }
    }
}

typealias GmailSyncState = WardrobeSchemaV2.GmailSyncState
