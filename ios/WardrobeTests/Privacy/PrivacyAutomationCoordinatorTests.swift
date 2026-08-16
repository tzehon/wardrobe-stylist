import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacyAutomationCoordinatorTests {
    private final class FakeReminderTimeStore: DailyReminderTimeStoring {
        var stored: DailyReminderTime = .defaultMorning
        var saves: [DailyReminderTime] = []
        var removeCalls = 0
        var saveSucceeds = true

        func load() -> DailyReminderTime { stored }
        func save(_ time: DailyReminderTime) -> Bool {
            guard saveSucceeds else { return false }
            stored = time
            saves.append(time)
            return true
        }
        func remove() -> Bool {
            removeCalls += 1
            stored = .defaultMorning
            return true
        }
    }
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

    @Test func enablingReminderSchedulesAndPersistsTheUserSelectedTime() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        let timeStore = FakeReminderTimeStore()
        var scheduled: [DailyReminderTime] = []
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { time in scheduled.append(time); return true },
            reminderTimeStore: timeStore
        )
        let chosen = try #require(DailyReminderTime(hour: 18, minute: 20))

        #expect(await coordinator.setDailyReminderEnabled(true, time: chosen))

        #expect(scheduled == [chosen])
        #expect(timeStore.saves == [chosen])
        #expect(coordinator.reminderTime == chosen)
        #expect(controls.preferences?.dailyReminderEnabled == true)
    }

    @Test func changingEnabledReminderTimeReschedulesAndPersistsOnlyAfterSuccess() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        let timeStore = FakeReminderTimeStore()
        let old = try #require(DailyReminderTime(hour: 7, minute: 30))
        _ = timeStore.save(old)
        timeStore.saves = []
        var scheduled: [DailyReminderTime] = []
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { time in scheduled.append(time); return true },
            reminderTimeStore: timeStore
        )
        let chosen = try #require(DailyReminderTime(hour: 8, minute: 45))

        #expect(await coordinator.setDailyReminderTime(chosen))

        #expect(scheduled == [chosen])
        #expect(timeStore.saves == [chosen])
        #expect(coordinator.reminderTime == chosen)
    }

    @Test func failedTimeReschedulePreservesPriorPersistedChoiceWithoutDisablingReminder() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        let timeStore = FakeReminderTimeStore()
        let old = try #require(DailyReminderTime(hour: 6, minute: 10))
        _ = timeStore.save(old)
        timeStore.saves = []
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in throw FixtureError.expected },
            reminderTimeStore: timeStore
        )
        let attempted = try #require(DailyReminderTime(hour: 9, minute: 0))

        #expect(await coordinator.setDailyReminderTime(attempted) == false)

        #expect(timeStore.saves.isEmpty)
        #expect(coordinator.reminderTime == old)
        #expect(controls.preferences?.dailyReminderEnabled == true)
        #expect(coordinator.state == .failed(.notificationPermissionDenied))
    }

    @Test func failedTimePersistenceIsSurfacedAndDoesNotChangeStoredChoice() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        let timeStore = FakeReminderTimeStore()
        let old = try #require(DailyReminderTime(hour: 7, minute: 0))
        timeStore.stored = old
        timeStore.saveSucceeds = false
        var scheduled: [DailyReminderTime] = []
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { time in scheduled.append(time); return true },
            reminderTimeStore: timeStore
        )
        let attempted = try #require(DailyReminderTime(hour: 11, minute: 25))

        #expect(await coordinator.setDailyReminderTime(attempted) == false)

        #expect(coordinator.reminderTime == old)
        #expect(scheduled == [attempted, old])
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
        #expect(controls.preferences?.dailyReminderEnabled == true)
    }

    @Test func failedInitialTimePersistenceCompensatesPreferenceAndSystemWork() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        let timeStore = FakeReminderTimeStore()
        timeStore.saveSucceeds = false
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in true },
            disableReminder: { disableCalls += 1 },
            reminderTimeStore: timeStore
        )

        #expect(await coordinator.setDailyReminderEnabled(true) == false)

        #expect(disableCalls == 1)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
    }

    @Test func failedTimePersistenceAndFailedRestoreDisableTheReminder() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        let timeStore = FakeReminderTimeStore()
        timeStore.saveSucceeds = false
        var enableCalls = 0
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in
                enableCalls += 1
                return enableCalls == 1
            },
            disableReminder: { disableCalls += 1 },
            reminderTimeStore: timeStore
        )
        let attempted = try #require(DailyReminderTime(hour: 13, minute: 35))

        #expect(await coordinator.setDailyReminderTime(attempted) == false)

        #expect(enableCalls == 2)
        #expect(disableCalls == 1)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
    }

    @Test func choosingTimeWhileReminderIsOffDoesNotRequestPermissionOrPersist() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        let timeStore = FakeReminderTimeStore()
        var enableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in enableCalls += 1; return true },
            reminderTimeStore: timeStore
        )
        let chosen = try #require(DailyReminderTime(hour: 10, minute: 5))

        #expect(await coordinator.setDailyReminderTime(chosen) == false)

        #expect(enableCalls == 0)
        #expect(timeStore.saves.isEmpty)
        #expect(coordinator.reminderTime == .defaultMorning)
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
        disableReminder: @escaping @MainActor () -> Void = {},
        reminderTimeStore: any DailyReminderTimeStoring = FakeReminderTimeStore()
    ) -> PrivacyAutomationCoordinator {
        PrivacyAutomationCoordinator(
            controls: controls,
            scheduleBackground: scheduleBackground,
            cancelBackground: cancelBackground,
            enableReminder: enableReminder,
            disableReminder: disableReminder,
            reminderTimeStore: reminderTimeStore
        )
    }
}
