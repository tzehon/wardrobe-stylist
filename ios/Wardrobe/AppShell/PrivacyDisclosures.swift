import Foundation

/// One durable, reviewable description of a connected feature's data flow.
/// Settings and Today both use these values so their explanations cannot drift.
struct PrivacyDisclosure: Equatable, Sendable {
    let title: String
    let summary: String
    let dataShared: [String]
    let destination: String
    let result: String

    static let receiptAnalysis = Self(
        title: "Receipt analysis",
        summary: "When you start an import, Wardrobe reads likely purchase messages through Google's read-only Gmail API and filters candidates on this device.",
        dataShared: [
            "A validated sender domain, sanitized subject, and either structured product fields or a limited, redacted product-text excerpt",
            "A Gmail message identifier reaches only the developer backend for response correlation and is removed before Anthropic processing",
            "No Gmail write, delete, send, label, or settings access"
        ],
        destination: "The minimized fields are sent over an encrypted connection to the developer-operated Wardrobe backend, which removes the Gmail identifier and uses Anthropic Claude to extract clothing details. Full sender addresses and raw message bodies are not sent to Anthropic.",
        result: "Extracted wardrobe items are saved in your local catalog. You choose when a manual import starts."
    )

    static let wardrobeStyling = Self(
        title: "AI styling",
        summary: "When you ask for a look, Wardrobe creates a compact text description of your catalog and recent wear history.",
        dataShared: [
            "Item identifiers, names, categories, brands, colors, and materials",
            "Recently worn item identifiers",
            "Per-item rating summaries: average rating and rating count",
            "Wardrobe photos and Gmail messages are not included in styling requests"
        ],
        destination: "Those details are sent over an encrypted connection to the developer-operated Wardrobe backend, which uses Anthropic Claude to propose a look. Free-text feedback, outfit rationales, and rating dates are not sent.",
        result: "The recommendation returns to this device. A request is sent only after you tap a styling action."
    )
}

/// App Store-facing links remain disabled until real HTTPS destinations are
/// supplied in Info.plist. Placeholder values are deliberately rejected.
struct AppExternalLinks: Equatable, Sendable {
    static let privacyPolicyInfoKey = "PRIVACY_POLICY_URL"
    static let supportInfoKey = "SUPPORT_URL"

    let privacyPolicyURL: URL?
    let supportURL: URL?

    init(infoDictionary: [String: Any]) {
        privacyPolicyURL = Self.validReleaseURL(
            infoDictionary[Self.privacyPolicyInfoKey] as? String
        )
        supportURL = Self.validReleaseURL(
            infoDictionary[Self.supportInfoKey] as? String
        )
    }

    static var current: Self {
        Self(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    static func validReleaseURL(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              !Self.isPlaceholder(host: host, fullValue: trimmed.lowercased()) else {
            return nil
        }
        return components.url
    }

    private static func isPlaceholder(host: String, fullValue: String) -> Bool {
        let placeholderFragments = [
            "example.com",
            "example.net",
            "example.org",
            "localhost",
            ".invalid",
            ".test",
            "your-domain",
            "yourdomain",
            "placeholder",
            "replace-me"
        ]
        return placeholderFragments.contains { host.contains($0) || fullValue.contains($0) }
    }
}
