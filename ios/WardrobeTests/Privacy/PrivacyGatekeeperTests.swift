import Foundation
import Testing

@testable import Wardrobe

struct PrivacyGatekeeperTests {
    @Test func defaultsDenyAndCurrentGrantAllowsStylingOnly() {
        let gate = PrivacyGatekeeper()
        #expect(gate.decision(for: .aiStyling, preferences: .defaultDeny)
            == .denied(.stylingConsentRequired))

        var granted = AccountPrivacyPreferences(
            wardrobeStylingConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeRequirements.current.wardrobeStyling,
                grantedAt: .now
            )
        )
        #expect(gate.decision(for: .aiStyling, preferences: granted) == .allowed)
        #expect(gate.decision(for: .dailyReminder, preferences: granted)
            == .denied(.dailyReminderDisabled))
        granted.dailyReminderEnabled = true
        #expect(gate.decision(for: .dailyReminder, preferences: granted) == .allowed)
    }

    @Test func staleNoticeAndUnsupportedFormatFailClosed() {
        let gate = PrivacyGatekeeper()
        let stale = AccountPrivacyPreferences(
            wardrobeStylingConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeVersion(rawValue: 1),
                grantedAt: .now
            ),
            dailyReminderEnabled: true
        )
        #expect(gate.decision(for: .aiStyling, preferences: stale)
            == .denied(.stylingConsentRequired))
        #expect(gate.decision(
            for: .aiStyling,
            preferences: AccountPrivacyPreferences(formatVersion: 999)
        ) == .denied(.preferencesUnavailable))
    }
}
