import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct PrivacySettingsControllerTests {
    @Test func deviceSettingsGrantAndWithdrawStyling() async {
        let store = SettingsPrivacyStore()
        let controls = PrivacyControls(subjectID: .deviceLocal, store: store)
        let automation = PrivacyAutomationCoordinator(
            controls: controls,
            enableReminder: { _ in true },
            disableReminder: {},
            reminderTimeStore: SettingsReminderStore()
        )
        let settings = DevicePrivacySettings(controls: controls, automation: automation)
        await settings.load()
        #expect(await settings.grantStyling())
        #expect(settings.controls.decision(for: .aiStyling) == .allowed)
        #expect(await settings.setReminderEnabled(true))
        #expect(await settings.withdrawStyling())
        #expect(settings.controls.decision(for: .aiStyling)
            == .denied(.stylingConsentRequired))
    }

    @Test func stylingDisclosureMatchesOccasionPayloadAndExplainsOnDemandUse() throws {
        let request = RecommendRequest(
            items: [],
            recentlyWornIds: [],
            occasion: "Outdoor wedding"
        )
        let payload = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request))
                as? [String: Any]
        )

        #expect(payload["occasion"] as? String == "Outdoor wedding")
        #expect(PrivacyDisclosure.wardrobeStyling.dataShared.contains {
            $0.localizedCaseInsensitiveContains("occasion")
                && $0.localizedCaseInsensitiveContains("context")
        })
        #expect(
            PrivacyDisclosure.wardrobeStyling.overview
                .localizedCaseInsensitiveContains("occasion or context")
        )
        #expect(PrivacyNoticeRequirements.current.wardrobeStyling.rawValue == 3)
        #expect(PrivacyDisclosure.wardrobeStyling.dataShared.contains {
            $0.contains("photos") && $0.contains("not included")
        })
        #expect(PrivacyDisclosure.wardrobeStyling.result.contains("only after you tap"))
    }
}

private actor SettingsPrivacyStore: PrivacyPreferencesStoring {
    private var value = AccountPrivacyPreferences.defaultDeny
    func load(for _: PrivacySubjectID) -> PrivacyPreferencesLoadResult { .loaded(value) }
    func save(_ preferences: AccountPrivacyPreferences, for _: PrivacySubjectID) {
        value = preferences
    }
    func remove(for _: PrivacySubjectID) { value = .defaultDeny }
}

@MainActor
private final class SettingsReminderStore: DailyReminderTimeStoring {
    func load() -> DailyReminderTime { .defaultMorning }
    func save(_: DailyReminderTime) -> Bool { true }
    func remove() -> Bool { true }
}
