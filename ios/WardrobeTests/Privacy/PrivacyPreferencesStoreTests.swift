import Foundation
import Testing

@testable import Wardrobe

struct PrivacyPreferencesStoreTests {
    @Test func missingDefaultsDenyAndRoundTripDeviceChoice() async throws {
        let suite = "wardrobe.privacy.tests.\(UUID().uuidString)"
        let store = UserDefaultsPrivacyPreferencesStore(suiteName: suite)
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        #expect(await store.load(for: .deviceLocal) == .loaded(.defaultDeny))
        let preferences = AccountPrivacyPreferences(
            wardrobeStylingConsent: PrivacyConsentGrant(
                noticeVersion: PrivacyNoticeRequirements.current.wardrobeStyling,
                grantedAt: Date(timeIntervalSince1970: 1)
            ),
            dailyReminderEnabled: true
        )
        try await store.save(preferences, for: .deviceLocal)
        #expect(await store.load(for: .deviceLocal) == .loaded(preferences))
        await store.remove(for: .deviceLocal)
        #expect(await store.load(for: .deviceLocal) == .loaded(.defaultDeny))
    }

    @Test func corruptValueFailsClosed() async {
        let suite = "wardrobe.privacy.tests.\(UUID().uuidString)"
        let store = UserDefaultsPrivacyPreferencesStore(suiteName: suite)
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        await store.replaceRawDataForTesting(Data("not-json".utf8), for: .deviceLocal)
        #expect(await store.load(for: .deviceLocal) == .unavailable(.corruptData))
    }
}
