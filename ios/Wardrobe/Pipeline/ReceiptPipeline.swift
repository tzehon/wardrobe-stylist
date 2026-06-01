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

    /// Runs one full sync. Safe to call repeatedly — dedup keeps the same
    /// receipt from producing duplicate items.
    func sync(
        query: String = ReceiptPipeline.defaultQuery,
        maxMessages: Int = 30
    ) async {
        // 1. Snapshot the catalog up front so we can dedup against it later.
        //    Doing this *before* any `await` keeps the SwiftData call in the
        //    same actor-execution slice as the @MainActor pipeline, which is
        //    needed because mainContext.fetch interleaved with async awaits
        //    later in the loop crashes inside SwiftData on iOS 26.
        var seenForMessage: [String: Set<String>] = [:]
        do {
            let existing = try modelContext.fetch(FetchDescriptor<Item>())
            for item in existing {
                guard let msgId = item.sourceMsgId else { continue }
                seenForMessage[msgId, default: []].insert(item.name.lowercased())
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
                    let alreadySeen = seenForMessage[ref.id] ?? []
                    let outcome = try await processMessage(ref, alreadySeenNames: alreadySeen)
                    itemsAdded += outcome.itemsAdded
                    if outcome.wasCandidate { candidates += 1 }
                    if !outcome.persistedNames.isEmpty {
                        seenForMessage[ref.id, default: []].formUnion(outcome.persistedNames)
                    }
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
        var persistedNames: Set<String>
    }

    private func processMessage(
        _ ref: GmailMessageList.MessageRef,
        alreadySeenNames: Set<String>
    ) async throws -> MessageOutcome {
        let message = try await gmailClient.getMessage(id: ref.id)
        let signals = SignalsExtractor.makeSignals(from: message)
        let score = CandidateClassifier.classify(signals)
        guard score.likelyPurchase else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: false, persistedNames: [])
        }

        let snippet = String(signals.bodyText.prefix(Self.snippetCharLimit))
        guard !snippet.isEmpty else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedNames: [])
        }

        let response = try await extractClient.extract(ExtractRequest(
            sourceMsgId: ref.id,
            sender: signals.senderAddress,
            subject: signals.subject,
            snippet: snippet
        ))
        guard response.isFashion else {
            return MessageOutcome(itemsAdded: 0, wasCandidate: true, persistedNames: [])
        }

        let result = try ingest(
            response.items,
            sourceMsgId: ref.id,
            internalDate: message.internalDate,
            alreadySeenNames: alreadySeenNames
        )
        return MessageOutcome(
            itemsAdded: result.added,
            wasCandidate: true,
            persistedNames: result.persistedNames
        )
    }

    // MARK: - Persistence

    /// Maps `ExtractedItem`s onto SwiftData `Item`s and persists.
    ///
    /// Dedup rule: an item is a duplicate if there's already an Item with the
    /// same `sourceMsgId` AND a case-insensitive matching `name`. That keeps
    /// repeated sync runs of the same email idempotent without preventing the
    /// catalog from seeing the same product across different orders.
    private func ingest(
        _ items: [ExtractedItem],
        sourceMsgId: String,
        internalDate: String?,
        alreadySeenNames: Set<String>
    ) throws -> (added: Int, persistedNames: Set<String>) {
        // Dedup is driven by the snapshot `sync()` built up front — no fetch
        // calls in here, only insert + save. See the comment in `sync()`.
        let purchaseDate = internalDate.flatMap(Self.parseGmailInternalDate)
        var seen = alreadySeenNames
        var persisted = Set<String>()
        var added = 0
        for extracted in items {
            let key = extracted.name.lowercased()
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

    /// Gmail's `internalDate` is milliseconds-since-epoch as a string.
    private static func parseGmailInternalDate(_ raw: String) -> Date? {
        guard let ms = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
