import CryptoKit
import Foundation

/// Opaque, provider-neutral persistence namespace for one wardrobe account.
///
/// OAuth provider identifiers never become model values directly. Instead, the
/// stable `PrivacySubjectID` is deterministically hashed into this local key.
/// That lets a restored account see the same records without coupling the
/// SwiftData schema to Google, an email address, or another user-facing value.
struct WardrobeAccountScope: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Scope used while no external account is active. Manual/photo items are
    /// shared across every scope; this key namespaces local outfit history.
    static let deviceLocal = Self(rawValue: "device-local:v1")

    static func external(_ subjectID: PrivacySubjectID) -> Self {
        precondition(subjectID.isExternal, "Account scope requires an external stable subject")
        let input = Data("wardrobe-account:v1:\(subjectID.rawValue)".utf8)
        let digest = SHA256.hash(data: input)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return Self(rawValue: "external:v1:\(hex)")
    }

    init(activeExternalSubject subjectID: PrivacySubjectID?) {
        self = subjectID.map(Self.external) ?? .deviceLocal
    }
}

/// Central account-visibility policy. Keeping it pure makes every UI and
/// backend boundary use exactly the same rules:
///
/// - manual/photo items are device-local and shared;
/// - email items belong only to their importing account;
/// - outfits and wear history belong only to the scope that created them;
/// - legacy unscoped email/history rows are never shown implicitly.
enum WardrobeAccountFilter {
    static func isVisible(_ item: Item, in scope: WardrobeAccountScope) -> Bool {
        switch item.source {
        case .manual, .photo:
            true
        case .email:
            item.accountSubjectKey == scope.rawValue
        }
    }

    static func isVisible(_ outfit: Outfit, in scope: WardrobeAccountScope) -> Bool {
        outfit.accountSubjectKey == scope.rawValue
    }

    static func isVisible(_ wearLog: WearLog, in scope: WardrobeAccountScope) -> Bool {
        wearLog.accountSubjectKey == scope.rawValue
    }

    static func visibleItems(
        from items: [Item],
        in scope: WardrobeAccountScope
    ) -> [Item] {
        items.filter { isVisible($0, in: scope) }
    }

    static func visibleOutfits(
        from outfits: [Outfit],
        in scope: WardrobeAccountScope
    ) -> [Outfit] {
        outfits.filter { isVisible($0, in: scope) }
    }

    static func visibleWearLogs(
        from wearLogs: [WearLog],
        in scope: WardrobeAccountScope
    ) -> [WearLog] {
        wearLogs.filter { isVisible($0, in: scope) }
    }
}
