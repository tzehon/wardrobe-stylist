import Foundation

struct PrivacyNoticeVersion: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

struct PrivacyConsentGrant: Codable, Equatable, Sendable {
    let noticeVersion: PrivacyNoticeVersion
    let grantedAt: Date
}

struct PrivacyNoticeRequirements: Equatable, Sendable {
    let wardrobeStyling: PrivacyNoticeVersion

    static let current = Self(
        // v3 also discloses optional user-entered occasion/context text.
        wardrobeStyling: PrivacyNoticeVersion(rawValue: 3)
    )
}
