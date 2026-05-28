import Foundation

/// Helpers for descending into a Gmail message's MIME tree.
///
/// Gmail returns a recursive `payload` with optional `parts`. We need to:
///   1. flatten leaves (the actual content carriers),
///   2. pick the best text body (prefer plaintext, fall back to HTML),
///   3. enumerate attachments for separate fetch.
enum MessageWalker {

    /// All leaf parts (those with no further `parts`), depth-first.
    static func leafParts(of root: GmailMessagePart) -> [GmailMessagePart] {
        let children = root.parts ?? []
        if children.isEmpty { return [root] }
        return children.flatMap(leafParts(of:))
    }

    /// Decoded UTF-8 body for the best textual leaf — `text/plain` if present, otherwise
    /// `text/html`. Returns the chosen mimeType and decoded text.
    static func bestText(of message: GmailMessage) -> (mimeType: String, text: String)? {
        guard let payload = message.payload else { return nil }
        let textLeaves = leafParts(of: payload).filter {
            ($0.mimeType ?? "").hasPrefix("text/")
        }
        let chosen = textLeaves.first(where: { $0.mimeType == "text/plain" })
            ?? textLeaves.first(where: { $0.mimeType == "text/html" })
        guard let part = chosen,
              let encoded = part.body?.data,
              let data = Base64URL.decode(encoded),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return (part.mimeType ?? "text/plain", text)
    }

    /// Leaf parts that look like attachments — they carry an `attachmentId` that can be
    /// fed into `attachments.get`.
    static func attachmentParts(of message: GmailMessage) -> [GmailMessagePart] {
        guard let payload = message.payload else { return [] }
        return leafParts(of: payload).filter { $0.body?.attachmentId != nil }
    }

    /// Looks up a header value by case-insensitive name (e.g. "Subject", "From").
    static func headerValue(_ name: String, in part: GmailMessagePart) -> String? {
        part.headers?.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value
    }
}
