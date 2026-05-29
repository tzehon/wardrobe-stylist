import Foundation

/// Bridge from a `GmailMessage` (Phase 1a) to a `CandidateSignals` bundle the
/// Tier 0 classifier can read. Stays in `Wardrobe/Receipts/` because none of
/// this touches Gmail HTTP — it only consumes already-fetched message data.
enum SignalsExtractor {

    static func makeSignals(from message: GmailMessage) -> CandidateSignals {
        let from = message.payload.flatMap { MessageWalker.headerValue("From", in: $0) }
        let subject = message.payload.flatMap { MessageWalker.headerValue("Subject", in: $0) } ?? ""
        let (address, domain) = parseSender(from)

        let bodyText: String
        if let best = MessageWalker.bestText(of: message) {
            bodyText = best.mimeType.lowercased().hasPrefix("text/html")
                ? HTMLStripper.strip(best.text)
                : best.text
        } else {
            bodyText = ""
        }

        return CandidateSignals(
            senderAddress: address,
            senderDomain: domain,
            subject: subject,
            bodyText: bodyText,
            labels: message.labelIds ?? [],
            hasAttachments: !MessageWalker.attachmentParts(of: message).isEmpty
        )
    }

    /// Parses an RFC 5322 `From` header value:
    ///   - `"Orders" <orders@everlane.com>` → `("orders@everlane.com", "everlane.com")`
    ///   - `orders@everlane.com`            → same
    ///   - empty / malformed                → `(nil, nil)`
    static func parseSender(_ raw: String?) -> (address: String?, domain: String?) {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return (nil, nil)
        }

        // Prefer the bit inside <...> if present.
        let candidate: String
        if let lt = trimmed.firstIndex(of: "<"),
           let gt = trimmed[lt...].firstIndex(of: ">"),
           lt < gt {
            candidate = String(trimmed[trimmed.index(after: lt)..<gt])
        } else {
            candidate = trimmed
        }

        let lower = candidate.lowercased().trimmingCharacters(in: .whitespaces)
        let parts = lower.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return (nil, nil)
        }
        return (lower, String(parts[1]))
    }
}
