import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacySettingsControllerTests {
    private actor FakeStore: PrivacyPreferencesStoring {
        enum FixtureFailure: Error { case saveFailed }

        private var values: [PrivacySubjectID: AccountPrivacyPreferences] = [:]
        private var failSaveSubjects: Set<PrivacySubjectID> = []
        private var removedSubjects: [PrivacySubjectID] = []

        func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult {
            .loaded(values[subjectID] ?? .defaultDeny)
        }

        func save(
            _ preferences: AccountPrivacyPreferences,
            for subjectID: PrivacySubjectID
        ) async throws {
            if failSaveSubjects.contains(subjectID) {
                throw FixtureFailure.saveFailed
            }
            values[subjectID] = preferences
        }

        func remove(for subjectID: PrivacySubjectID) async {
            values.removeValue(forKey: subjectID)
            removedSubjects.append(subjectID)
        }

        func seed(
            _ preferences: AccountPrivacyPreferences,
            for subjectID: PrivacySubjectID
        ) {
            values[subjectID] = preferences
        }

        func setSaveFailure(_ shouldFail: Bool, for subjectID: PrivacySubjectID) {
            if shouldFail {
                failSaveSubjects.insert(subjectID)
            } else {
                failSaveSubjects.remove(subjectID)
            }
        }

        func value(for subjectID: PrivacySubjectID) -> AccountPrivacyPreferences? {
            values[subjectID]
        }

        func removals() -> [PrivacySubjectID] {
            removedSubjects
        }
    }

    private let accountSubject = PrivacySubjectID.external("stable-test-account")
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func accountExitDisablesBothAutomationsAndRetainsSeparateConsentGrants() async {
        let store = FakeStore()
        await store.seed(receiptPreferences(backgroundEnabled: true), for: accountSubject)
        await store.seed(stylingPreferences(reminderEnabled: true), for: .deviceLocal)

        var backgroundCancellations = 0
        var reminderCancellations = 0
        let fixture = makeFixture(
            store: store,
            cancelBackground: { backgroundCancellations += 1 },
            disableReminder: { reminderCancellations += 1 }
        )

        #expect(await fixture.gmail.prepareForAccountExit())

        let account = await store.value(for: accountSubject)
        let device = await store.value(for: .deviceLocal)
        #expect(account?.receiptAnalysisConsent != nil)
        #expect(account?.backgroundReceiptSyncEnabled == false)
        #expect(device?.wardrobeStylingConsent != nil)
        #expect(device?.dailyReminderEnabled == false)
        #expect(backgroundCancellations == 1)
        #expect(reminderCancellations == 1)
    }

    @Test func revocationClearsOnlyAccountReceiptPreferences() async {
        let store = FakeStore()
        await store.seed(receiptPreferences(backgroundEnabled: false), for: accountSubject)
        await store.seed(stylingPreferences(reminderEnabled: false), for: .deviceLocal)
        let fixture = makeFixture(store: store)
        await fixture.gmail.load()

        await fixture.gmail.clearRevokedAccountPreferences()

        #expect(await store.value(for: accountSubject) == nil)
        #expect(await store.value(for: .deviceLocal)?.wardrobeStylingConsent != nil)
        #expect(await store.removals() == [accountSubject])
        #expect(fixture.gmail.controls.preferences == .defaultDeny)
    }

    @Test func failedReminderShutdownPreventsAccountExit() async {
        let store = FakeStore()
        await store.seed(receiptPreferences(backgroundEnabled: true), for: accountSubject)
        await store.seed(stylingPreferences(reminderEnabled: true), for: .deviceLocal)
        await store.setSaveFailure(true, for: .deviceLocal)
        var reminderCancellations = 0
        let fixture = makeFixture(
            store: store,
            disableReminder: { reminderCancellations += 1 }
        )

        #expect(await fixture.gmail.prepareForAccountExit() == false)

        #expect(await store.value(for: .deviceLocal)?.dailyReminderEnabled == true)
        #expect(reminderCancellations == 0)
        #expect(
            fixture.gmail.errorMessage
                == PrivacyAutomationFailure.preferenceSaveFailed.userMessage
        )
    }

    @Test func grantingStylingChangesOnlyTheDeviceLocalSubject() async {
        let store = FakeStore()
        await store.seed(receiptPreferences(backgroundEnabled: false), for: accountSubject)
        let fixture = makeFixture(store: store)

        #expect(await fixture.device.grantStyling())

        #expect(await store.value(for: .deviceLocal)?.wardrobeStylingConsent != nil)
        #expect(await store.value(for: accountSubject)?.wardrobeStylingConsent == nil)
    }

    private func makeFixture(
        store: FakeStore,
        cancelBackground: @escaping @MainActor () -> Void = {},
        disableReminder: @escaping @MainActor () -> Void = {}
    ) -> (gmail: GmailPrivacySettings, device: DevicePrivacySettings) {
        let fixedNow = now
        let deviceControls = PrivacyControls(
            subjectID: .deviceLocal,
            store: store,
            now: { fixedNow }
        )
        let deviceAutomation = PrivacyAutomationCoordinator(
            controls: deviceControls,
            scheduleBackground: {},
            cancelBackground: {},
            enableReminder: { _ in true },
            disableReminder: disableReminder
        )
        let device = DevicePrivacySettings(
            controls: deviceControls,
            automation: deviceAutomation
        )

        let gmailControls = PrivacyControls(
            subjectID: accountSubject,
            store: store,
            now: { fixedNow }
        )
        let gmailAutomation = PrivacyAutomationCoordinator(
            controls: gmailControls,
            scheduleBackground: {},
            cancelBackground: cancelBackground,
            enableReminder: { _ in true },
            disableReminder: {}
        )
        let gmail = GmailPrivacySettings(
            subjectID: accountSubject,
            store: store,
            devicePrivacy: device,
            controls: gmailControls,
            automation: gmailAutomation
        )
        return (gmail, device)
    }

    private func receiptPreferences(backgroundEnabled: Bool) -> AccountPrivacyPreferences {
        AccountPrivacyPreferences(
            receiptAnalysisConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeRequirements.current.receiptAnalysis,
                grantedAt: now
            ),
            backgroundReceiptSyncEnabled: backgroundEnabled
        )
    }

    private func stylingPreferences(reminderEnabled: Bool) -> AccountPrivacyPreferences {
        AccountPrivacyPreferences(
            wardrobeStylingConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeRequirements.current.wardrobeStyling,
                grantedAt: now
            ),
            dailyReminderEnabled: reminderEnabled
        )
    }
}

struct PrivacyDisclosureTests {
    @Test func releaseLinksRequireNonPlaceholderHTTPSURLs() {
        let links = AppExternalLinks(infoDictionary: [
            AppExternalLinks.privacyPolicyInfoKey: " https://wardrobe.example.app/privacy ",
            AppExternalLinks.supportInfoKey: "http://wardrobe.example.app/support"
        ])

        #expect(links.privacyPolicyURL?.absoluteString == "https://wardrobe.example.app/privacy")
        #expect(links.supportURL == nil)
        #expect(AppExternalLinks.validReleaseURL("https://example.com/privacy") == nil)
        #expect(AppExternalLinks.validReleaseURL("https://your-domain.invalid/support") == nil)
        #expect(AppExternalLinks.validReleaseURL("not a URL") == nil)
    }

    @Test func disclosuresNameEveryRemoteProcessorWithoutUnsupportedPromises() {
        let disclosures = [
            PrivacyDisclosure.receiptAnalysis,
            PrivacyDisclosure.wardrobeStyling
        ]

        for disclosure in disclosures {
            #expect(disclosure.destination.contains("developer-operated Wardrobe backend"))
            #expect(disclosure.destination.contains("Anthropic Claude"))
            #expect(disclosure.destination.localizedCaseInsensitiveContains("never retained") == false)
            #expect(disclosure.destination.localizedCaseInsensitiveContains("not trained") == false)
        }
        #expect(PrivacyDisclosure.wardrobeStyling.dataShared.contains {
            $0.contains("photos") && $0.contains("not included")
        })
    }
}
