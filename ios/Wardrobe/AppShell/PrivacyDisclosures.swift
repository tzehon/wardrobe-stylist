import Foundation

/// One durable, reviewable description of a connected feature's data flow.
/// Settings and Today both use these values so their explanations cannot drift.
struct PrivacyDisclosure: Equatable, Sendable {
    let title: String
    let summary: String
    let overview: String
    let dataShared: [String]
    let destination: String
    let result: String

    static let wardrobeStyling = Self(
        title: "AI styling",
        summary: "When you ask for a look, Wardrobe creates a compact text description of your catalog and recent wear history.",
        overview: "If you allow styling and ask for a look, a compact text catalog, recent item identifiers, per-item average rating and rating count, and any occasion or context you enter are sent to the developer-operated backend and Anthropic Claude. Free-text feedback, outfit rationales, rating dates, and wardrobe photos are not included in styling requests.",
        dataShared: [
            "Item identifiers, names, categories, brands, colors, and materials",
            "Recently worn item identifiers",
            "Per-item rating summaries: average rating and rating count",
            "Any occasion or context you enter for the requested look",
            "Wardrobe photos are not included in styling requests"
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
