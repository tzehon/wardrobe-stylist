import Foundation

/// Account-scoped privacy choices. The initializer is intentionally deny-by-
/// default: neither AI flow is consented and neither automation is enabled.
struct AccountPrivacyPreferences: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var receiptAnalysisConsent: PrivacyConsentGrant?
    var wardrobeStylingConsent: PrivacyConsentGrant?
    var backgroundReceiptSyncEnabled: Bool
    var dailyReminderEnabled: Bool

    init(
        formatVersion: Int = currentFormatVersion,
        receiptAnalysisConsent: PrivacyConsentGrant? = nil,
        wardrobeStylingConsent: PrivacyConsentGrant? = nil,
        backgroundReceiptSyncEnabled: Bool = false,
        dailyReminderEnabled: Bool = false
    ) {
        self.formatVersion = formatVersion
        self.receiptAnalysisConsent = receiptAnalysisConsent
        self.wardrobeStylingConsent = wardrobeStylingConsent
        self.backgroundReceiptSyncEnabled = backgroundReceiptSyncEnabled
        self.dailyReminderEnabled = dailyReminderEnabled
    }

    static let defaultDeny = Self()
}
