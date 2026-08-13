import Foundation

/// Version of one user-facing data-use notice. Consent is valid only when the
/// recorded version exactly matches the version currently required by the app.
struct PrivacyNoticeVersion: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Evidence that a subject accepted one specific version of a data-use notice.
struct PrivacyConsentGrant: Codable, Equatable, Sendable {
    let noticeVersion: PrivacyNoticeVersion
    let grantedAt: Date
}

/// Independently versioned notice requirements for the two AI data flows.
/// Keeping these separate lets a material change to one flow invalidate only
/// the consent that must actually be renewed.
struct PrivacyNoticeRequirements: Equatable, Sendable {
    let receiptAnalysis: PrivacyNoticeVersion
    let wardrobeStyling: PrivacyNoticeVersion

    static let current = Self(
        receiptAnalysis: PrivacyNoticeVersion(rawValue: 1),
        wardrobeStyling: PrivacyNoticeVersion(rawValue: 1)
    )
}
