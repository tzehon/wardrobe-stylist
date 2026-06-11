import Foundation
import Observation
import SwiftData

/// Orchestrates the full receipt → catalog flow:
///
///   GmailReadOnlyClient (list+get, never mutating)
///       → SignalsExtractor + CandidateClassifier (Tier 0, on-device, fast)
///       → ExtractClient `/extract` (Tier 2, Claude Haiku, fashion attributes)
///       → SwiftData `Item` (with dedup against existing rows from the same email)
///
/// Stateful only for UI observation. All real work is per-message and isolated:
/// one bad message (network blip, malformed payload) bumps the errors counter
/// and the loop moves on.
@MainActor
@Observable
final class ReceiptPipeline {

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

    /// Maximum chars of body snippet sent to the backend. Backend's
    /// `ExtractRequest.snippet` is capped at 8000; keep a small buffer.
    private static let snippetCharLimit = 7500

    /// Default Gmail search — broad enough to catch most receipts but not so
    /// broad it pulls in every newsletter. `category:purchases` is Gmail's
    /// auto-applied label for transactional mail; the OR keywords backstop
    /// users whose Gmail isn't auto-categorising.
    static let defaultQuery =
        #"(category:purchases OR receipt OR invoice OR "your order") newer_than:90d"#

    init(
        gmailClient: GmailReadOnlyClient,
        extractClient: ExtractClient,
        modelContext: ModelContext
    ) {
        self.gmailClient = gmailClient
        self.extractClient = extractClient
        self.modelContext = modelContext
    }

    /// Runs one full sync. Safe to call repeatedly — catalog-wide dedup keeps the
    /// same product from producing duplicate items, even when one order arrives
    /// across several emails (e.g. an order confirmation *and* a dispatch email).
    func sync(
        query: String = ReceiptPipeline.defaultQuery,
        maxMessages: Int = 200
    ) async {
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
        do {
            let existing = try modelContext.fetch(FetchDescriptor<Item>())
            var duplicates: [Item] = []
            for item in existing.sorted(by: Self.earliestFirst) where item.source == .email {
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
        } catch {
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
            for try await ref in gmailClient.allMessages(query: query, includeSpamTrash: true) {
                refs.append(ref)
                if refs.count >= maxMessages { break }
            }
            let total = refs.count
            state = .running(processed: 0, total: total)

            // 3. Per-message: fetch, classify, maybe extract, maybe persist.
            var itemsAdded = 0
            var candidates = 0
            var errors = 0

            for (index, ref) in refs.enumerated() {
                state = .running(processed: index, total: total)
                do {
                    let outcome = try await processMessage(ref, seenIdentities: seenIdentities)
                    itemsAdded += outcome.itemsAdded
                    if outcome.wasCandidate { candidates += 1 }
                    seenIdentities.formUnion(outcome.persistedIdentities)
                } catch {
                    errors += 1
                }
            }

            state = .complete(itemsAdded: itemsAdded, candidates: candidates, errors: errors)
        } catch {
            state = .failed(message: error.localizedDescription)
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
        let message = try await gmailClient.getMessage(id: ref.id)
        let signals = SignalsExtractor.makeSignals(from: message)
        let score = CandidateClassifier.classify(signals)
        guard score.likelyPurchase else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: false, persistedIdentities: [])
        }

        let snippet = String(signals.bodyText.prefix(Self.snippetCharLimit))
        guard !snippet.isEmpty else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedIdentities: [])
        }

        let response = try await extractClient.extract(ExtractRequest(
            sourceMsgId: ref.id,
            sender: signals.senderAddress,
            subject: signals.subject,
            snippet: snippet
        ))
        guard response.isFashion else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedIdentities: [])
        }

        let result = try ingest(
            response.items,
            sourceMsgId: ref.id,
            internalDate: message.internalDate,
            seenIdentities: seenIdentities
        )
        return MessageOutcome(
            itemsAdded: result.added,
            wasCandidate: true,
            persistedIdentities: result.persistedIdentities
        )
    }

    // MARK: - Persistence

    /// Maps `ExtractedItem`s onto SwiftData `Item`s and persists.
    ///
    /// Dedup rule: an item is a duplicate if the catalog already holds an
    /// email-sourced Item with the same brand+name+category identity (see
    /// `identityKey`). Keying on identity rather than `sourceMsgId` collapses the
    /// same product arriving across multiple emails of one order (confirmation +
    /// dispatch) into a single catalog entry, and keeps re-syncs idempotent.
    private func ingest(
        _ items: [ExtractedItem],
        sourceMsgId: String,
        internalDate: String?,
        seenIdentities: Set<String>
    ) throws -> (added: Int, persistedIdentities: Set<String>) {
        // Dedup is driven by the snapshot `sync()` built up front — no fetch
        // calls in here, only insert + save. See the comment in `sync()`.
        let purchaseDate = internalDate.flatMap(Self.parseGmailInternalDate)
        var seen = seenIdentities
        var persisted = Set<String>()
        var added = 0
        for extracted in items {
            let key = Self.identityKey(
                brand: extracted.brand,
                name: extracted.name,
                category: extracted.category.rawValue
            )
            if seen.contains(key) { continue }
            seen.insert(key)
            persisted.insert(key)
            let item = Item(
                name: extracted.name,
                category: extracted.category.rawValue,
                brand: extracted.brand,
                colors: extracted.color.map { [$0] } ?? [],
                material: extracted.material,
                styleNotes: extracted.styleNotes,
                source: .email,
                purchaseDate: purchaseDate,
                sourceMsgId: sourceMsgId
            )
            modelContext.insert(item)
            added += 1
        }
        if added > 0 {
            try modelContext.save()
        }
        return (added, persisted)
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
