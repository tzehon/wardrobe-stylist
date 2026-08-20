import Foundation

/// Device-local choices for remote styling and its optional reminder.
struct AccountPrivacyPreferences: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var wardrobeStylingConsent: PrivacyConsentGrant?
    var dailyReminderEnabled: Bool

    init(
        formatVersion: Int = currentFormatVersion,
        wardrobeStylingConsent: PrivacyConsentGrant? = nil,
        dailyReminderEnabled: Bool = false
    ) {
        self.formatVersion = formatVersion
        self.wardrobeStylingConsent = wardrobeStylingConsent
        self.dailyReminderEnabled = dailyReminderEnabled
    }

    static let defaultDeny = Self()
}
