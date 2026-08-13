import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacyAutomationCoordinatorTests {
    private actor FakeStore: PrivacyPreferencesStoring {
        enum FixtureError: Error { case saveFailed }

        var value = AccountPrivacyPreferences.defaultDeny
        var failSave = false
        var saveCount = 0

        func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult {
            .loaded(value)
        }

        func save(
            _ preferences: AccountPrivacyPreferences,
            for subjectID: PrivacySubjectID
        ) async throws {
            if failSave { throw FixtureError.saveFailed }
            value = preferences
            saveCount += 1
        }

        func remove(for subjectID: PrivacySubjectID) async {}

        func setFailSave(_ value: Bool) { failSave = value }
        func setValue(_ value: AccountPrivacyPreferences) { self.value = value }
        func storedValue() -> AccountPrivacyPreferences { value }
        func saves() -> Int { saveCount }
    }

    private let subject = PrivacySubjectID.external("automation-test-subject")
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func backgroundEnableRequiresConsentBeforeScheduling() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        var scheduleCalls = 0
        let coordinator = makeCoordinator(controls: controls) {
            scheduleCalls += 1
        }

        #expect(await coordinator.setBackgroundReceiptSyncEnabled(true) == false)

        #expect(scheduleCalls == 0)
        #expect(await store.saves() == 0)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(coordinator.state == .failed(.receiptConsentRequired))
    }

    @Test func backgroundScheduleFailureLeavesPreferenceOff() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        let coordinator = makeCoordinator(controls: controls) {
            throw FixtureError.expected
        }

        #expect(await coordinator.setBackgroundReceiptSyncEnabled(true) == false)

        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(coordinator.state == .failed(.backgroundSchedulingFailed))
    }

    @Test func backgroundSaveFailureCompensatesByCancellingScheduledWork() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        await store.setFailSave(true)
        var scheduleCalls = 0
        var cancelCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            scheduleBackground: { scheduleCalls += 1 },
            cancelBackground: { cancelCalls += 1 }
        )

        #expect(await coordinator.setBackgroundReceiptSyncEnabled(true) == false)

        #expect(scheduleCalls == 1)
        #expect(cancelCalls == 1)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
    }

    @Test func failedBackgroundDisableDoesNotPretendPendingWorkWasCancelled() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        try await controls.setBackgroundReceiptSyncEnabled(true)
        await store.setFailSave(true)
        var cancelCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            cancelBackground: { cancelCalls += 1 }
        )

        #expect(await coordinator.setBackgroundReceiptSyncEnabled(false) == false)

        #expect(cancelCalls == 0)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == true)
    }

    @Test func deniedNotificationPermissionLeavesReminderOff() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        var enableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in
                enableCalls += 1
                return false
            }
        )

        #expect(await coordinator.setDailyReminderEnabled(true) == false)

        #expect(enableCalls == 1)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .failed(.notificationPermissionDenied))
    }

    @Test func reminderSaveFailureRemovesTheScheduledReminder() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        await store.setFailSave(true)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in true },
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.setDailyReminderEnabled(true) == false)

        #expect(disableCalls == 1)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
    }

    @Test func withdrawingConsentPersistsBeforeRemovingDependentWork() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        try await controls.setBackgroundReceiptSyncEnabled(true)
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        var cancelCalls = 0
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            cancelBackground: { cancelCalls += 1 },
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.withdrawReceiptAnalysis())
        #expect(await coordinator.withdrawWardrobeStyling())

        #expect(cancelCalls == 1)
        #expect(disableCalls == 1)
        #expect(controls.preferences == .defaultDeny)
        #expect(await store.storedValue() == .defaultDeny)
    }

    @Test func signOutDisablesAutomationsButRetainsConsentGrants() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantReceiptAnalysis()
        try await controls.setBackgroundReceiptSyncEnabled(true)
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        var cancelCalls = 0
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            cancelBackground: { cancelCalls += 1 },
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.disableAutomationsForSignOut())

        #expect(cancelCalls == 1)
        #expect(disableCalls == 1)
        #expect(controls.preferences?.receiptAnalysisConsent != nil)
        #expect(controls.preferences?.wardrobeStylingConsent != nil)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(controls.preferences?.dailyReminderEnabled == false)
    }

    @Test func reconciliationCancelsDefaultDenyWorkWithoutWriting() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        var cancelCalls = 0
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            cancelBackground: { cancelCalls += 1 },
            disableReminder: { disableCalls += 1 }
        )

        await coordinator.reconcile()

        #expect(cancelCalls == 1)
        #expect(disableCalls == 1)
        #expect(await store.saves() == 0)
        #expect(coordinator.state == .ready)
    }

    @Test func reconciliationClearsStaleAutomationSwitches() async {
        let store = FakeStore()
        await store.setValue(AccountPrivacyPreferences(
            receiptAnalysisConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeVersion(rawValue: 0),
                grantedAt: fixedDate
            ),
            wardrobeStylingConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeVersion(rawValue: 0),
                grantedAt: fixedDate
            ),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        ))
        let controls = makeControls(store: store)
        var cancelCalls = 0
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            cancelBackground: { cancelCalls += 1 },
            disableReminder: { disableCalls += 1 }
        )

        await coordinator.reconcile()

        #expect(cancelCalls == 1)
        #expect(disableCalls == 1)
        #expect(controls.preferences?.backgroundReceiptSyncEnabled == false)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .ready)
    }

    private enum FixtureError: Error { case expected }

    private func makeControls(store: FakeStore) -> PrivacyControls {
        let date = fixedDate
        return PrivacyControls(subjectID: subject, store: store, now: { date })
    }

    private func makeCoordinator(
        controls: PrivacyControls,
        scheduleBackground: @escaping @MainActor () throws -> Void = {},
        cancelBackground: @escaping @MainActor () -> Void = {},
        enableReminder: @escaping @MainActor (DailyReminderTime) async throws -> Bool = { _ in true },
        disableReminder: @escaping @MainActor () -> Void = {}
    ) -> PrivacyAutomationCoordinator {
        PrivacyAutomationCoordinator(
            controls: controls,
            scheduleBackground: scheduleBackground,
            cancelBackground: cancelBackground,
            enableReminder: enableReminder,
            disableReminder: disableReminder
        )
    }
}
