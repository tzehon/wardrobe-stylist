import Foundation
import Observation
import SwiftData

/// Orchestrates the full receipt → catalog flow:
///
///   GmailReadOnlyClient (list+get, never mutating)
///       → SignalsExtractor + CandidateClassifier (Tier 0, on-device, fast)
///       → JSON-LD or redacted product excerpt (on-device privacy boundary)
///       → ExtractClient `/extract` (Tier 2, Claude Haiku, fashion attributes)
///       → SwiftData `Item` (with dedup against existing rows from the same email)
///
/// Stateful only for UI observation. All real work is per-message and isolated:
/// one bad message (network blip, malformed payload) bumps the errors counter
/// and the loop moves on.
@MainActor
@Observable
final class ReceiptPipeline {

    private enum ProcessingError: Error, Sendable {
        case extractionContractViolation
    }

    enum SyncMode: Sendable {
        case manual
        case background

        var privacyCapability: PrivacyCapability {
            switch self {
            case .manual: .manualReceiptImport
            case .background: .backgroundReceiptImport
            }
        }
    }

    enum State: Equatable {
        case idle
        case running(processed: Int, total: Int)
        case complete(itemsAdded: Int, candidates: Int, errors: Int)
        case failed(message: String)
    }

    var state: State = .idle

    private let gmailClient: GmailReadOnlyClient
    private let extractClient: ExtractClient
    private let modelContext: ModelContext
    private let privacyGate: any PrivacyGateChecking
    private let privacySubjectID: PrivacySubjectID
    private let accountScope: WardrobeAccountScope
    private let processedStateStore: GmailProcessedStateStore

    /// Default Gmail search — broad enough to catch most receipts but not so
    /// broad it pulls in every newsletter. `category:purchases` is Gmail's
    /// auto-applied label for transactional mail; the OR keywords backstop
    /// users whose Gmail isn't auto-categorising.
    ///
    /// No date window: the user wants *all* orders regardless of age, so recency
    /// is bounded only by `maxMessages` (Gmail returns newest-first). A proper
    /// incremental/paged backfill is the long-term answer for very large
    /// mailboxes — see the large-mailbox-scaling note.
    static let defaultQuery =
        #"category:purchases OR receipt OR invoice OR "your order""#

    init(
        gmailClient: GmailReadOnlyClient,
        extractClient: ExtractClient,
        modelContext: ModelContext,
        privacyGate: any PrivacyGateChecking = StoredPrivacyGatekeeper(),
        privacySubjectID: PrivacySubjectID,
        processedStateStore: GmailProcessedStateStore? = nil
    ) {
        self.gmailClient = gmailClient
        self.extractClient = extractClient
        self.modelContext = modelContext
        self.privacyGate = privacyGate
        self.privacySubjectID = privacySubjectID
        self.accountScope = .external(privacySubjectID)
        self.processedStateStore = processedStateStore ?? GmailProcessedStateStore(
            modelContext: modelContext,
            subjectID: privacySubjectID
        )
    }

    /// Runs one full sync. Safe to call repeatedly — catalog-wide dedup keeps the
    /// same product from producing duplicate items, even when one order arrives
    /// across several emails (e.g. an order confirmation *and* a dispatch email).
    func sync(
        query: String = ReceiptPipeline.defaultQuery,
        maxMessages: Int = 1000,
        mode: SyncMode = .manual
    ) async {
        guard !Task.isCancelled else {
            state = .failed(message: Self.cancellationMessage)
            return
        }
        let decision = await privacyGate.decision(
            for: mode.privacyCapability,
            subjectID: privacySubjectID
        )
        guard !Task.isCancelled else {
            state = .failed(message: Self.cancellationMessage)
            return
        }
        guard decision.isAllowed else {
            state = .failed(message: Self.privacyMessage(for: decision))
            return
        }

        // 1. Snapshot + de-duplicate the existing catalog up front. Doing all the
        //    SwiftData work here, *before* any `await`, keeps it in the same
        //    actor-execution slice as the @MainActor pipeline — mainContext
        //    fetch/save interleaved with awaits later in the loop crashes inside
        //    SwiftData on iOS 26.
        //
        //    Dedup identity is brand+name+category (case/space-normalised),
        //    scoped to email-sourced items (manual/photo items are user-curated
        //    and never auto-removed). The sweep also heals any duplicates already
        //    in the store from before dedup went catalog-wide.
        var seenIdentities: Set<String> = []
        let processedMessageIDs: Set<String>
        do {
            try Task.checkCancellation()
            let existing = try modelContext.fetch(FetchDescriptor<Item>())
            var duplicates: [Item] = []
            for item in existing.sorted(by: Self.earliestFirst)
            where item.source == .email && item.accountSubjectKey == accountScope.rawValue {
                let key = Self.identityKey(
                    brand: item.brand, name: item.name, category: item.category
                )
                if seenIdentities.insert(key).inserted == false {
                    duplicates.append(item)
                }
            }
            if !duplicates.isEmpty {
                for duplicate in duplicates { modelContext.delete(duplicate) }
                try modelContext.save()
            }
            processedMessageIDs = try processedStateStore.processedMessageIDs()
        } catch is CancellationError {
            modelContext.rollback()
            state = .failed(message: Self.cancellationMessage)
            return
        } catch {
            modelContext.rollback()
            state = .failed(
                message: "Failed to load existing catalog: \(error.localizedDescription)"
            )
            return
        }

        state = .running(processed: 0, total: 0)
        do {
            // 2. Discover candidate message ids. allMessages auto-paginates;
            //    we bound it by maxMessages to keep first-run costs predictable.
            var refs: [GmailMessageList.MessageRef] = []
            var discoveredMessageIDs = processedMessageIDs
            if maxMessages > 0 {
                for try await ref in gmailClient.allMessages(
                    query: query,
                    includeSpamTrash: false
                ) {
                    try Task.checkCancellation()
                    // Re-listing is intentionally cheap and resumable: known
                    // terminal messages never incur messages.get or backend
                    // work, and do not consume the per-run backfill budget.
                    guard discoveredMessageIDs.insert(ref.id).inserted else { continue }
                    refs.append(ref)
                    if refs.count >= maxMessages { break }
                }
            }
            let total = refs.count
            state = .running(processed: 0, total: total)

            // 3. Per-message: fetch, classify, maybe extract, maybe persist.
            var itemsAdded = 0
            var candidates = 0
            var errors = 0

            for (index, ref) in refs.enumerated() {
                do {
                    try Task.checkCancellation()
                } catch {
                    state = .failed(message: Self.cancellationMessage)
                    return
                }
                state = .running(processed: index, total: total)
                do {
                    let outcome = try await processMessage(ref, seenIdentities: seenIdentities)
                    itemsAdded += outcome.itemsAdded
                    if outcome.wasCandidate { candidates += 1 }
                    seenIdentities.formUnion(outcome.persistedIdentities)
                } catch is CancellationError {
                    state = .failed(message: Self.cancellationMessage)
                    return
                } catch where Task.isCancelled {
                    state = .failed(message: Self.cancellationMessage)
                    return
                } catch {
                    errors += 1
                }
            }

            guard !Task.isCancelled else {
                state = .failed(message: Self.cancellationMessage)
                return
            }
            state = .complete(itemsAdded: itemsAdded, candidates: candidates, errors: errors)
        } catch is CancellationError {
            state = .failed(message: Self.cancellationMessage)
        } catch where Task.isCancelled {
            state = .failed(message: Self.cancellationMessage)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private static let cancellationMessage = "Receipt sync was cancelled."

    private static func privacyMessage(for decision: PrivacyGateDecision) -> String {
        switch decision {
        case .allowed:
            ""
        case .denied(.receiptConsentRequired):
            "Review data use and allow receipt analysis before syncing Gmail."
        case .denied(.backgroundReceiptSyncDisabled):
            "Background receipt sync is turned off."
        case .denied(.preferencesUnavailable):
            "Privacy preferences are unavailable. Receipt sync was not started."
        case .denied:
            "Receipt sync is not allowed by the current privacy settings."
        }
    }

    // MARK: - Per-message

    private struct MessageOutcome {
        var itemsAdded: Int
        var wasCandidate: Bool
        var persistedIdentities: Set<String>
    }

    private func processMessage(
        _ ref: GmailMessageList.MessageRef,
        seenIdentities: Set<String>
    ) async throws -> MessageOutcome {
        try Task.checkCancellation()
        let message = try await gmailClient.getMessage(id: ref.id)
        try Task.checkCancellation()
        let signals = SignalsExtractor.makeSignals(from: message)
        let score = CandidateClassifier.classify(signals)
        guard score.likelyPurchase else {
            try commitTerminalOutcome(
                .notPurchase,
                messageID: ref.id,
                gmailHistoryID: message.historyId
            )
            return MessageOutcome(itemsAdded: 0, wasCandidate: false, persistedIdentities: [])
        }

        guard let payload = ReceiptPayloadBuilder.makePayload(
            message: message,
            signals: signals
        ) else {
            try commitTerminalOutcome(
                .emptyContent,
                messageID: ref.id,
                gmailHistoryID: message.historyId
            )
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedIdentities: [])
        }

        let response = try await extractClient.extract(ExtractRequest(
            sourceMsgId: ref.id,
            sender: payload.senderDomain,
            subject: payload.subject,
            snippet: payload.snippet
        ))
        try Task.checkCancellation()
        // Decode success is not enough: an older or compromised backend can
        // still violate the shared semantic contract. Neither direction may
        // become a terminal ledger result, because that would prevent a later
        // healthy sync from retrying the Gmail message.
        guard response.isFashion == !response.items.isEmpty else {
            throw ProcessingError.extractionContractViolation
        }
        guard response.isFashion else {
            try commitTerminalOutcome(
                .notFashion,
                messageID: ref.id,
                gmailHistoryID: message.historyId
            )
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedIdentities: [])
        }

        let plan = makeIngestPlan(
            response.items,
            seenIdentities: seenIdentities
        )
        try Task.checkCancellation()
        let outcome: ProcessedGmailMessageOutcome = plan.items.isEmpty ? .duplicate : .imported
        let committed = try processedStateStore.commitProcessed(
            messageID: ref.id,
            outcome: outcome,
            gmailHistoryID: message.historyId
        ) {
            try Task.checkCancellation()
            return try stageIngest(
                plan,
                sourceMsgId: ref.id,
                internalDate: message.internalDate
            )
        }
        let result = committed.result
        return MessageOutcome(
            itemsAdded: result.added,
            wasCandidate: true,
            persistedIdentities: result.persistedIdentities
        )
    }

    // MARK: - Persistence

    private func commitTerminalOutcome(
        _ outcome: ProcessedGmailMessageOutcome,
        messageID: String,
        gmailHistoryID: String?
    ) throws {
        try Task.checkCancellation()
        try processedStateStore.markProcessed(
            messageID: messageID,
            outcome: outcome,
            gmailHistoryID: gmailHistoryID
        )
    }

    private struct IngestPlan {
        let items: [ExtractedItem]
        let persistedIdentities: Set<String>
    }

    /// Selects new catalog identities without mutating SwiftData. This lets us
    /// decide the ledger outcome before entering the one atomic save boundary.
    private func makeIngestPlan(
        _ items: [ExtractedItem],
        seenIdentities: Set<String>
    ) -> IngestPlan {
        var seen = seenIdentities
        var planned: [ExtractedItem] = []
        var persisted = Set<String>()
        for extracted in items {
            let key = Self.identityKey(
                brand: extracted.brand,
                name: extracted.name,
                category: extracted.category.rawValue
            )
            guard seen.insert(key).inserted else { continue }
            planned.append(extracted)
            persisted.insert(key)
        }
        return IngestPlan(items: planned, persistedIdentities: persisted)
    }

    /// Maps the preselected `ExtractedItem`s onto SwiftData `Item`s. The caller
    /// owns the save; in production that is `commitProcessed`, which persists
    /// these items and the terminal processed-message row transactionally.
    ///
    /// Dedup rule: an item is a duplicate if the catalog already holds an
    /// email-sourced Item with the same brand+name+category identity (see
    /// `identityKey`). Keying on identity rather than `sourceMsgId` collapses the
    /// same product arriving across multiple emails of one order (confirmation +
    /// dispatch) into a single catalog entry, and keeps re-syncs idempotent.
    private func stageIngest(
        _ plan: IngestPlan,
        sourceMsgId: String,
        internalDate: String?
    ) throws -> (added: Int, persistedIdentities: Set<String>) {
        let purchaseDate = internalDate.flatMap(Self.parseGmailInternalDate)
        for extracted in plan.items {
            let item = Item(
                name: extracted.name,
                category: extracted.category.rawValue,
                brand: extracted.brand,
                colors: extracted.color.map { [$0] } ?? [],
                material: extracted.material,
                styleNotes: extracted.styleNotes,
                source: .email,
                purchaseDate: purchaseDate,
                sourceMsgId: sourceMsgId,
                imageURL: extracted.imageUrl,
                accountSubjectKey: accountScope.rawValue
            )
            modelContext.insert(item)
        }
        return (plan.items.count, plan.persistedIdentities)
    }

    /// Stable de-dup identity for a catalog item: brand + name + category,
    /// lower-cased and trimmed, joined with a unit separator that won't occur in
    /// the fields themselves.
    private static func identityKey(brand: String?, name: String, category: String) -> String {
        func norm(_ value: String) -> String {
            value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return [norm(brand ?? ""), norm(name), norm(category)].joined(separator: "\u{1F}")
    }

    /// Sort comparator putting earlier purchase dates first (nil dates last), so
    /// the dedup sweep keeps the earliest-known copy of a product.
    private static func earliestFirst(_ a: Item, _ b: Item) -> Bool {
        (a.purchaseDate ?? .distantFuture) < (b.purchaseDate ?? .distantFuture)
    }

    /// Gmail's `internalDate` is milliseconds-since-epoch as a string.
    private static func parseGmailInternalDate(_ raw: String) -> Date? {
        guard let ms = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
