import Foundation
import Testing

@testable import Wardrobe

struct PrivacyGatekeeperTests {
    private let required = PrivacyNoticeRequirements(
        receiptAnalysis: PrivacyNoticeVersion(rawValue: 3),
        wardrobeStyling: PrivacyNoticeVersion(rawValue: 8)
    )

    @Test func defaultPreferencesDenyEveryCapability() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)

        #expect(gatekeeper.decision(for: .manualReceiptImport, preferences: .defaultDeny)
            == .denied(.receiptConsentRequired))
        #expect(gatekeeper.decision(for: .backgroundReceiptImport, preferences: .defaultDeny)
            == .denied(.receiptConsentRequired))
        #expect(gatekeeper.decision(for: .aiStyling, preferences: .defaultDeny)
            == .denied(.stylingConsentRequired))
        #expect(gatekeeper.decision(for: .dailyReminder, preferences: .defaultDeny)
            == .denied(.stylingConsentRequired))
    }

    @Test func currentReceiptConsentAllowsManualImportOnlyUntilBackgroundIsEnabled() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        var preferences = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 3)
        )

        #expect(gatekeeper.decision(for: .manualReceiptImport, preferences: preferences) == .allowed)
        #expect(gatekeeper.decision(for: .backgroundReceiptImport, preferences: preferences)
            == .denied(.backgroundReceiptSyncDisabled))
        #expect(gatekeeper.decision(for: .aiStyling, preferences: preferences)
            == .denied(.stylingConsentRequired))

        preferences.backgroundReceiptSyncEnabled = true
        #expect(gatekeeper.decision(for: .backgroundReceiptImport, preferences: preferences) == .allowed)
    }

    @Test func backgroundToggleNeverSubstitutesForReceiptConsent() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        let preferences = AccountPrivacyPreferences(backgroundReceiptSyncEnabled: true)

        #expect(gatekeeper.decision(for: .manualReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))
        #expect(gatekeeper.decision(for: .backgroundReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))
    }

    @Test func currentStylingConsentAllowsAIOnlyUntilReminderIsEnabled() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        var preferences = AccountPrivacyPreferences(
            wardrobeStylingConsent: grant(version: 8)
        )

        #expect(gatekeeper.decision(for: .aiStyling, preferences: preferences) == .allowed)
        #expect(gatekeeper.decision(for: .dailyReminder, preferences: preferences)
            == .denied(.dailyReminderDisabled))
        #expect(gatekeeper.decision(for: .manualReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))

        preferences.dailyReminderEnabled = true
        #expect(gatekeeper.decision(for: .dailyReminder, preferences: preferences) == .allowed)
    }

    @Test func reminderToggleNeverSubstitutesForStylingConsent() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        let preferences = AccountPrivacyPreferences(dailyReminderEnabled: true)

        #expect(gatekeeper.decision(for: .aiStyling, preferences: preferences)
            == .denied(.stylingConsentRequired))
        #expect(gatekeeper.decision(for: .dailyReminder, preferences: preferences)
            == .denied(.stylingConsentRequired))
    }

    @Test func bothCurrentConsentsAndTogglesAllowAllCapabilities() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        let preferences = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 3),
            wardrobeStylingConsent: grant(version: 8),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )

        for capability in PrivacyCapability.allCases {
            #expect(gatekeeper.decision(for: capability, preferences: preferences).isAllowed)
        }
    }

    @Test func receiptNoticeBumpInvalidatesOnlyReceiptCapabilities() {
        let oldRequirements = PrivacyNoticeRequirements(
            receiptAnalysis: PrivacyNoticeVersion(rawValue: 3),
            wardrobeStyling: PrivacyNoticeVersion(rawValue: 8)
        )
        let preferences = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 3),
            wardrobeStylingConsent: grant(version: 8),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )
        let before = PrivacyGatekeeper(requiredNotices: oldRequirements)
        #expect(before.decision(for: .manualReceiptImport, preferences: preferences) == .allowed)
        #expect(before.decision(for: .backgroundReceiptImport, preferences: preferences) == .allowed)

        let bumped = PrivacyGatekeeper(requiredNotices: PrivacyNoticeRequirements(
            receiptAnalysis: PrivacyNoticeVersion(rawValue: 4),
            wardrobeStyling: PrivacyNoticeVersion(rawValue: 8)
        ))
        #expect(bumped.decision(for: .manualReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))
        #expect(bumped.decision(for: .backgroundReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))
        #expect(bumped.decision(for: .aiStyling, preferences: preferences) == .allowed)
        #expect(bumped.decision(for: .dailyReminder, preferences: preferences) == .allowed)
    }

    @Test func stylingNoticeBumpInvalidatesOnlyStylingCapabilities() {
        let preferences = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 3),
            wardrobeStylingConsent: grant(version: 8),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )
        let bumped = PrivacyGatekeeper(requiredNotices: PrivacyNoticeRequirements(
            receiptAnalysis: PrivacyNoticeVersion(rawValue: 3),
            wardrobeStyling: PrivacyNoticeVersion(rawValue: 9)
        ))

        #expect(bumped.decision(for: .manualReceiptImport, preferences: preferences) == .allowed)
        #expect(bumped.decision(for: .backgroundReceiptImport, preferences: preferences) == .allowed)
        #expect(bumped.decision(for: .aiStyling, preferences: preferences)
            == .denied(.stylingConsentRequired))
        #expect(bumped.decision(for: .dailyReminder, preferences: preferences)
            == .denied(.stylingConsentRequired))
    }

    @Test func futureGrantVersionDoesNotCountAsCurrentConsent() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        let preferences = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 4),
            wardrobeStylingConsent: grant(version: 9),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )

        #expect(gatekeeper.decision(for: .manualReceiptImport, preferences: preferences)
            == .denied(.receiptConsentRequired))
        #expect(gatekeeper.decision(for: .aiStyling, preferences: preferences)
            == .denied(.stylingConsentRequired))
    }

    @Test func unsupportedPreferenceFormatDeniesAsUnavailable() {
        let gatekeeper = PrivacyGatekeeper(requiredNotices: required)
        let preferences = AccountPrivacyPreferences(
            formatVersion: AccountPrivacyPreferences.currentFormatVersion + 1,
            receiptAnalysisConsent: grant(version: 3),
            wardrobeStylingConsent: grant(version: 8),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )

        for capability in PrivacyCapability.allCases {
            #expect(gatekeeper.decision(for: capability, preferences: preferences)
                == .denied(.preferencesUnavailable))
        }
    }

    private func grant(version: Int) -> PrivacyConsentGrant {
        PrivacyConsentGrant(
            noticeVersion: PrivacyNoticeVersion(rawValue: version),
            grantedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
