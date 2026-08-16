import Foundation
import SwiftData

/// Terminal result for a Gmail message the receipt pipeline has examined.
/// Failures are deliberately not terminal: they should be retried instead of
/// entering the processed ledger.
enum ProcessedGmailMessageOutcome: String, Codable, CaseIterable, Sendable {
    case notPurchase
    case emptyContent
    case notFashion
    case imported
    case duplicate
}

extension WardrobeSchemaV2 {
    /// Per-account ledger entry used to make receipt processing idempotent and
    /// to support incremental Gmail history without rescanning known messages.
    @Model
    final class ProcessedGmailMessage {
        /// Opaque composite key derived from account + Gmail message id.
        @Attribute(.unique) var scopedMessageKey: String
        var accountSubjectKey: String
        var gmailMessageID: String
        var processedAt: Date
        var outcomeRawValue: String
        var gmailHistoryID: String?

        var outcome: ProcessedGmailMessageOutcome? {
            get { ProcessedGmailMessageOutcome(rawValue: outcomeRawValue) }
            set { outcomeRawValue = newValue?.rawValue ?? outcomeRawValue }
        }

        init(
            scopedMessageKey: String,
            accountSubjectKey: String,
            gmailMessageID: String,
            processedAt: Date = .now,
            outcome: ProcessedGmailMessageOutcome,
            gmailHistoryID: String? = nil
        ) {
            self.scopedMessageKey = scopedMessageKey
            self.accountSubjectKey = accountSubjectKey
            self.gmailMessageID = gmailMessageID
            self.processedAt = processedAt
            self.outcomeRawValue = outcome.rawValue
            self.gmailHistoryID = gmailHistoryID
        }
    }
}

typealias ProcessedGmailMessage = WardrobeSchemaV2.ProcessedGmailMessage
