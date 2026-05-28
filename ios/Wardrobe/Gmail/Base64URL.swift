import Foundation

/// Base64url codec — the URL-safe variant Gmail uses for message bodies and attachments.
/// Differs from standard Base64 by using `-` instead of `+` and `_` instead of `/`, and by
/// allowing padding to be omitted.
enum Base64URL {
    /// Decodes a base64url string into bytes. Returns nil for malformed input.
    static func decode(_ string: String) -> Data? {
        var normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: normalized)
    }

    /// Encodes bytes as base64url (no padding) — provided for symmetry/tests.
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
