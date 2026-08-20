import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacyControlsTests {
    @Test func stylingGrantIsVersionedAndWithdrawalDisablesReminder() async throws {
        let store = TestPrivacyStore()
        let now = Date(timeIntervalSince1970: 123)
        let controls = PrivacyControls(
            subjectID: .deviceLocal,
            store: store,
            now: { now }
        )
        await controls.load()
        #expect(controls.decision(for: .aiStyling) == .denied(.stylingConsentRequired))

        try await controls.grantWardrobeStyling()
        #expect(controls.preferences?.wardrobeStylingConsent == PrivacyConsentGrant(
            noticeVersion: PrivacyNoticeRequirements.current.wardrobeStyling,
            grantedAt: now
        ))
        try await controls.setDailyReminderEnabled(true)
        #expect(controls.decision(for: .dailyReminder) == .allowed)

        try await controls.withdrawWardrobeStyling()
        #expect(controls.preferences?.wardrobeStylingConsent == nil)
        #expect(controls.preferences?.dailyReminderEnabled == false)
    }

    @Test func reminderCannotEnableWithoutStylingConsent() async {
        let controls = PrivacyControls(subjectID: .deviceLocal, store: TestPrivacyStore())
        await controls.load()
        await #expect(throws: PrivacyControlsFailure.stylingConsentRequired) {
            try await controls.setDailyReminderEnabled(true)
        }
    }
}

private actor TestPrivacyStore: PrivacyPreferencesStoring {
    private var value = AccountPrivacyPreferences.defaultDeny

    func load(for _: PrivacySubjectID) -> PrivacyPreferencesLoadResult { .loaded(value) }
    func save(_ preferences: AccountPrivacyPreferences, for _: PrivacySubjectID) {
        value = preferences
    }
    func remove(for _: PrivacySubjectID) { value = .defaultDeny }
}
