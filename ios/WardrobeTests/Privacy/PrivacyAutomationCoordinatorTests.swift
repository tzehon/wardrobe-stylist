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

        private var value: AccountPrivacyPreferences
        private var failSave = false
        private var saveCount = 0

        init(seed: AccountPrivacyPreferences = .defaultDeny) {
            value = seed
        }

        func load(for _: PrivacySubjectID) -> PrivacyPreferencesLoadResult {
            .loaded(value)
        }

        func save(
            _ preferences: AccountPrivacyPreferences,
            for _: PrivacySubjectID
        ) throws {
            if failSave { throw FixtureError.saveFailed }
            value = preferences
            saveCount += 1
        }

        func remove(for _: PrivacySubjectID) {
            value = .defaultDeny
        }

        func setFailSave(_ value: Bool) { failSave = value }
        func setValue(_ value: AccountPrivacyPreferences) { self.value = value }
        func storedValue() -> AccountPrivacyPreferences { value }
        func saves() -> Int { saveCount }
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func reminderEnableRequiresStylingConsentBeforeScheduling() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        var enableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            enableReminder: { _ in enableCalls += 1; return true }
        )

        #expect(await coordinator.setDailyReminderEnabled(true) == false)

        #expect(enableCalls == 0)
        #expect(await store.saves() == 0)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(coordinator.state == .failed(.stylingConsentRequired))
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

    @Test func privacySaveFailureRemovesTheScheduledReminder() async throws {
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

    @Test func failedDisableSaveDoesNotRemoveTheExistingReminder() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        await store.setFailSave(true)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.setDailyReminderEnabled(false) == false)

        #expect(disableCalls == 0)
        #expect(controls.preferences?.dailyReminderEnabled == true)
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

    @Test func initialTimePersistenceFailureCompensatesPreferenceAndSystemWork() async throws {
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

    @Test func failedTimeReschedulePreservesPriorChoiceAndEnabledReminder() async throws {
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

    @Test func failedTimePersistenceRestoresThePriorScheduledChoice() async throws {
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

    @Test func choosingTimeWhileReminderIsOffDoesNotScheduleOrPersist() async throws {
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
        #expect(coordinator.state == .failed(.stylingConsentRequired))
    }

    @Test func withdrawingConsentPersistsBeforeRemovingTheReminder() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.withdrawWardrobeStyling())

        #expect(disableCalls == 1)
        #expect(controls.preferences == .defaultDeny)
        #expect(await store.storedValue() == .defaultDeny)
    }

    @Test func failedConsentWithdrawalKeepsTheReminderAndConsentIntact() async throws {
        let store = FakeStore()
        let controls = makeControls(store: store)
        await controls.load()
        try await controls.grantWardrobeStyling()
        try await controls.setDailyReminderEnabled(true)
        let original = try #require(controls.preferences)
        await store.setFailSave(true)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            disableReminder: { disableCalls += 1 }
        )

        #expect(await coordinator.withdrawWardrobeStyling() == false)

        #expect(disableCalls == 0)
        #expect(controls.preferences == original)
        #expect(coordinator.state == .failed(.preferenceSaveFailed))
    }

    @Test func reconciliationCancelsDefaultDenyReminderWithoutWriting() async {
        let store = FakeStore()
        let controls = makeControls(store: store)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            disableReminder: { disableCalls += 1 }
        )

        await coordinator.reconcile()

        #expect(disableCalls == 1)
        #expect(await store.saves() == 0)
        #expect(coordinator.state == .ready)
    }

    @Test func reconciliationClearsAStaleReminderSwitchWithoutConsent() async {
        let store = FakeStore(seed: AccountPrivacyPreferences(dailyReminderEnabled: true))
        let controls = makeControls(store: store)
        var disableCalls = 0
        let coordinator = makeCoordinator(
            controls: controls,
            disableReminder: { disableCalls += 1 }
        )

        await coordinator.reconcile()

        #expect(disableCalls == 1)
        #expect(controls.preferences?.dailyReminderEnabled == false)
        #expect(await store.storedValue().dailyReminderEnabled == false)
        #expect(coordinator.state == .ready)
    }

    private enum FixtureError: Error { case expected }

    private func makeControls(store: FakeStore) -> PrivacyControls {
        let date = fixedDate
        return PrivacyControls(subjectID: .deviceLocal, store: store, now: { date })
    }

    private func makeCoordinator(
        controls: PrivacyControls,
        enableReminder: @escaping @MainActor (DailyReminderTime) async throws -> Bool = { _ in true },
        disableReminder: @escaping @MainActor () -> Void = {},
        reminderTimeStore: any DailyReminderTimeStoring = FakeReminderTimeStore()
    ) -> PrivacyAutomationCoordinator {
        PrivacyAutomationCoordinator(
            controls: controls,
            enableReminder: enableReminder,
            disableReminder: disableReminder,
            reminderTimeStore: reminderTimeStore
        )
    }
}
