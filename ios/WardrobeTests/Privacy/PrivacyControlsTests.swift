import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacyControlsTests {
    private let subject = PrivacySubjectID.external("stable-test-subject")
    private let notices = PrivacyNoticeRequirements(
        receiptAnalysis: PrivacyNoticeVersion(rawValue: 4),
        wardrobeStyling: PrivacyNoticeVersion(rawValue: 9)
    )
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private actor FakeStore: PrivacyPreferencesStoring {
        enum FixtureError: Error { case saveFailed }

        var values: [PrivacySubjectID: AccountPrivacyPreferences] = [:]
        var unavailable = false
        var failSave = false
        var saves = 0

        func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult {
            unavailable
                ? .unavailable(.corruptData)
                : .loaded(values[subjectID] ?? .defaultDeny)
        }

        func save(
            _ preferences: AccountPrivacyPreferences,
            for subjectID: PrivacySubjectID
        ) async throws {
            if failSave { throw FixtureError.saveFailed }
            saves += 1
            values[subjectID] = preferences
        }

        func remove(for subjectID: PrivacySubjectID) async {
            values.removeValue(forKey: subjectID)
        }

        func setUnavailable(_ value: Bool) { unavailable = value }
        func setFailSave(_ value: Bool) { failSave = value }
        func value(for subjectID: PrivacySubjectID) -> AccountPrivacyPreferences? { values[subjectID] }
        func saveCount() -> Int { saves }
    }

    @Test func loadMissingPreferencesIsDenyByDefault() async {
        let store = FakeStore()
        let controls = makeControls(store: store)

        await controls.load()

        #expect(controls.preferences == .defaultDeny)
    }

    @Test func grantsAreIndependentCurrentVersionAndTimestamped() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()

        try await controls.grantReceiptAnalysis()
        #expect(controls.preferences?.receiptAnalysisConsent == PrivacyConsentGrant(
            noticeVersion: notices.receiptAnalysis,
            grantedAt: date
        ))
        #expect(controls.preferences?.wardrobeStylingConsent == nil)

        try await controls.grantWardrobeStyling()
        #expect(controls.preferences?.wardrobeStylingConsent == PrivacyConsentGrant(
            noticeVersion: notices.wardrobeStyling,
            grantedAt: date
        ))
    }

    @Test func automationCannotEnableWithoutItsCurrentConsent() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()

        await #expect(throws: PrivacyControlsFailure.receiptConsentRequired) {
            try await controls.setBackgroundReceiptSyncEnabled(true)
        }
        await #expect(throws: PrivacyControlsFailure.stylingConsentRequired) {
            try await controls.setDailyReminderEnabled(true)
        }
        #expect(await store.saveCount() == 0)
        #expect(controls.preferences == .defaultDeny)
    }

    @Test func withdrawalAlsoTurnsOffDependentAutomation() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        try await controls.setBackgroundReceiptSyncEnabled(true)
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)

        try await controls.withdrawReceiptAnalysis()
        try await controls.withdrawWardrobeStyling()

        #expect(controls.preferences?.receiptAnalysisConsent == nil)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(controls.preferences?.wardrobeStylingConsent == nil)
        #expect(controls.preferences?.dailyReminderEnabled == false)
    }

    @Test func corruptPreferencesFailClosedAndCannotBeOverwritten() async {
        let store = FakeStore()
        await store.setUnavailable(true)
        let controls = makeControls(store: store)

        await controls.load()

        #expect(controls.state == .unavailable(.preferencesUnavailable))
        await #expect(throws: PrivacyControlsFailure.preferencesUnavailable) {
            try await controls.grantReceiptAnalysis()
        }
        #expect(await store.saveCount() == 0)
    }

    @Test func failedSaveDoesNotExposeOptimisticConsent() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        await store.setFailSave(true)

        await #expect(throws: PrivacyControlsFailure.saveFailed) {
            try await controls.grantWardrobeStyling()
        }

        #expect(controls.preferences == .defaultDeny)
        #expect(await store.value(for: subject) == nil)
    }

    private func makeControls(store: FakeStore) -> PrivacyControls {
        PrivacyControls(
            subjectID: subject,
            store: store,
            requiredNotices: notices,
            now: { date }
        )
    }
}
