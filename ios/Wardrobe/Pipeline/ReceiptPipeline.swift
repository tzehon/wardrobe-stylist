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

        // 1. Snapshot existing catalog identities up front. Doing all the
        //    SwiftData work here, *before* any `await`, keeps it in the same
        //    actor-execution slice as the @MainActor pipeline — mainContext
        //    fetch/save interleaved with awaits later in the loop crashes inside
        //    SwiftData on iOS 26.
        //
        //    Duplicate identity is brand+name+category (case/space-normalised),
        //    scoped to email-sourced items. Duplicates are never deleted: later
        //    rows retain a pointer to the earliest candidate so the user can
        //    distinguish a resend from two legitimately purchased pieces.
        var knownIdentities: [String: UUID] = [:]
        let processedMessageIDs: Set<String>
        do {
            try Task.checkCancellation()
            let existing = try modelContext.fetch(FetchDescriptor<Item>())
            var duplicateMarkersChanged = false
            for item in existing.sorted(by: Self.earliestFirst)
            where item.source == .email && item.accountSubjectKey == accountScope.rawValue {
                let key = Self.identityKey(
                    brand: item.brand, name: item.name, category: item.category
                )
                if let primaryID = knownIdentities[key] {
                    if item.possibleDuplicateOfItemID != primaryID {
                        item.possibleDuplicateOfItemID = primaryID
                        duplicateMarkersChanged = true
                    }
                } else {
                    knownIdentities[key] = item.id
                    if item.possibleDuplicateOfItemID != nil {
                        item.possibleDuplicateOfItemID = nil
                        duplicateMarkersChanged = true
                    }
                }
            }
            if duplicateMarkersChanged {
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
                    let outcome = try await processMessage(ref, knownIdentities: knownIdentities)
                    itemsAdded += outcome.itemsAdded
                    if outcome.wasCandidate { candidates += 1 }
                    for (identity, id) in outcome.newPrimaryIdentities
                    where knownIdentities[identity] == nil {
                        knownIdentities[identity] = id
                    }
                } catch is CancellationError {
                    state = .failed(message: Self.cancellationMessage)
                    return
                } catch where Task.isCancelled {
                    state = .failed(message: Self.cancellationMessage)
                    return
                } catch let authorizationError as AppAttestAuthorizationError {
                    // Authorization is shared by the whole import. Repeating a
                    // deterministic unsupported/configuration failure once per
                    // candidate only creates noise and unnecessary Gmail reads.
                    state = .failed(message: authorizationError.localizedDescription)
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
        var newPrimaryIdentities: [String: UUID]
    }

    private func processMessage(
        _ ref: GmailMessageList.MessageRef,
        knownIdentities: [String: UUID]
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
            return MessageOutcome(itemsAdded: 0, wasCandidate: false, newPrimaryIdentities: [:])
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
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, newPrimaryIdentities: [:])
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
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, newPrimaryIdentities: [:])
        }

        let plan = makeIngestPlan(
            response.items,
            knownIdentities: knownIdentities
        )
        try Task.checkCancellation()
        let committed = try processedStateStore.commitProcessed(
            messageID: ref.id,
            outcome: .imported,
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
            newPrimaryIdentities: result.newPrimaryIdentities
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
        struct Entry {
            let id: UUID
            let extracted: ExtractedItem
            let possibleDuplicateOfItemID: UUID?
        }

        let entries: [Entry]
        let newPrimaryIdentities: [String: UUID]
    }

    /// Plans every extracted purchase without mutating SwiftData. Same-identity
    /// items are retained and linked to the first candidate for human review.
    private func makeIngestPlan(
        _ items: [ExtractedItem],
        knownIdentities: [String: UUID]
    ) -> IngestPlan {
        var known = knownIdentities
        var planned: [IngestPlan.Entry] = []
        var newPrimaries: [String: UUID] = [:]
        for extracted in items {
            let key = Self.identityKey(
                brand: extracted.brand,
                name: extracted.name,
                category: extracted.category.rawValue
            )
            let id = UUID()
            let duplicateOf = known[key]
            planned.append(IngestPlan.Entry(
                id: id,
                extracted: extracted,
                possibleDuplicateOfItemID: duplicateOf
            ))
            if duplicateOf == nil {
                known[key] = id
                newPrimaries[key] = id
            }
        }
        return IngestPlan(entries: planned, newPrimaryIdentities: newPrimaries)
    }

    /// Maps the planned `ExtractedItem`s onto SwiftData `Item`s. The caller
    /// owns the save; in production that is `commitProcessed`, which persists
    /// these items and the terminal processed-message row transactionally.
    ///
    /// Possible-duplicate rule: matching brand+name+category values link to the
    /// earliest account-scoped import. No catalog row is silently discarded;
    /// processed-message ledgering, rather than destructive dedup, makes reruns
    /// of the same Gmail message idempotent.
    private func stageIngest(
        _ plan: IngestPlan,
        sourceMsgId: String,
        internalDate: String?
    ) throws -> (added: Int, newPrimaryIdentities: [String: UUID]) {
        let purchaseDate = internalDate.flatMap(Self.parseGmailInternalDate)
        for entry in plan.entries {
            let extracted = entry.extracted
            let item = Item(
                id: entry.id,
                name: extracted.name,
                category: extracted.category.rawValue,
                brand: extracted.brand,
                colors: extracted.color.map { [$0] } ?? [],
                size: extracted.size,
                material: extracted.material,
                styleNotes: extracted.styleNotes,
                source: .email,
                purchaseDate: purchaseDate,
                purchasePrice: extracted.price,
                purchaseCurrency: extracted.currency,
                sourceMsgId: sourceMsgId,
                imageURL: extracted.imageUrl,
                accountSubjectKey: accountScope.rawValue,
                extractionConfidence: ItemExtractionConfidence(
                    rawValue: extracted.confidence.rawValue
                ),
                possibleDuplicateOfItemID: entry.possibleDuplicateOfItemID,
                reviewState: .pendingReview
            )
            modelContext.insert(item)
        }
        return (plan.entries.count, plan.newPrimaryIdentities)
    }

    /// Stable possible-duplicate identity for a catalog item: brand + name + category,
    /// lower-cased and trimmed, joined with a unit separator that won't occur in
    /// the fields themselves.
    private static func identityKey(brand: String?, name: String, category: String) -> String {
        func norm(_ value: String) -> String {
            value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return [norm(brand ?? ""), norm(name), norm(category)].joined(separator: "\u{1F}")
    }

    /// Sort comparator putting earlier purchase dates first (nil dates last), so
    /// duplicate evidence points at the earliest-known copy of a product.
    private static func earliestFirst(_ a: Item, _ b: Item) -> Bool {
        let aDate = a.purchaseDate ?? .distantFuture
        let bDate = b.purchaseDate ?? .distantFuture
        if aDate != bDate { return aDate < bDate }
        return a.id.uuidString < b.id.uuidString
    }

    /// Gmail's `internalDate` is milliseconds-since-epoch as a string.
    private static func parseGmailInternalDate(_ raw: String) -> Date? {
        guard let ms = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
