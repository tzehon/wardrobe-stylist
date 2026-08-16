import Foundation
import Testing

@testable import Wardrobe

@Suite(.serialized)
struct PrivacyPreferencesStoreTests {
    private let subjectA = PrivacySubjectID.external("account-a")
    private let subjectB = PrivacySubjectID.external("account-b")

    @Test func subjectIDsAreOpaqueAndProviderNeutral() {
        #expect(PrivacySubjectID.deviceLocal.rawValue == "device-local:v1")
        #expect(PrivacySubjectID.external("stable-123").rawValue == "external:v1:stable-123")
        #expect(PrivacySubjectID.external("stable-123") == PrivacySubjectID.external("stable-123"))
        #expect(PrivacySubjectID.external("stable-123") != PrivacySubjectID.external("stable-456"))
    }

    @Test func missingPreferencesLoadAsDefaultDeny() async throws {
        let fixture = try makeFixture()

        let result = await fixture.store.load(for: subjectA)

        #expect(result == .loaded(.defaultDeny))
        let preferences = try #require(result.preferences)
        #expect(preferences.receiptAnalysisConsent == nil)
        #expect(preferences.wardrobeStylingConsent == nil)
        #expect(preferences.backgroundReceiptSyncEnabled == false)
        #expect(preferences.dailyReminderEnabled == false)
    }

    @Test func preferencesRoundTripWithIndependentConsentAndAutomationValues() async throws {
        let fixture = try makeFixture()
        let receiptGrant = PrivacyConsentGrant(
            noticeVersion: PrivacyNoticeVersion(rawValue: 1),
            grantedAt: Date(timeIntervalSince1970: 1_700_000_000.123)
        )
        let stylingGrant = PrivacyConsentGrant(
            noticeVersion: PrivacyNoticeVersion(rawValue: 7),
            grantedAt: Date(timeIntervalSince1970: 1_700_000_999.456)
        )
        let expected = AccountPrivacyPreferences(
            receiptAnalysisConsent: receiptGrant,
            wardrobeStylingConsent: stylingGrant,
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: false
        )

        try await fixture.store.save(expected, for: subjectA)

        #expect(await fixture.store.load(for: subjectA) == .loaded(expected))
    }

    @Test func subjectsAreIsolatedAndKeysDoNotContainRawIdentifiers() async throws {
        let fixture = try makeFixture()
        let onlyReceipt = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 1, time: 100),
            backgroundReceiptSyncEnabled: true
        )
        let onlyStyling = AccountPrivacyPreferences(
            wardrobeStylingConsent: grant(version: 1, time: 200),
            dailyReminderEnabled: true
        )

        try await fixture.store.save(onlyReceipt, for: subjectA)
        try await fixture.store.save(onlyStyling, for: subjectB)

        #expect(await fixture.store.load(for: subjectA) == .loaded(onlyReceipt))
        #expect(await fixture.store.load(for: subjectB) == .loaded(onlyStyling))

        let keyA = UserDefaultsPrivacyPreferencesStore.storageKey(
            for: subjectA,
            keyPrefix: fixture.keyPrefix
        )
        let keyB = UserDefaultsPrivacyPreferencesStore.storageKey(
            for: subjectB,
            keyPrefix: fixture.keyPrefix
        )
        #expect(keyA != keyB)
        #expect(keyA.contains(subjectA.rawValue) == false)
        #expect(keyB.contains(subjectB.rawValue) == false)
        #expect(await fixture.store.hasStoredDataForTesting(for: subjectA))
        #expect(await fixture.store.hasStoredDataForTesting(for: subjectB))
    }

    @Test func removingOneSubjectDoesNotRemoveAnother() async throws {
        let fixture = try makeFixture()
        let first = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 1, time: 100)
        )
        let second = AccountPrivacyPreferences(
            wardrobeStylingConsent: grant(version: 1, time: 200)
        )
        try await fixture.store.save(first, for: subjectA)
        try await fixture.store.save(second, for: subjectB)

        await fixture.store.remove(for: subjectA)

        #expect(await fixture.store.load(for: subjectA) == .loaded(.defaultDeny))
        #expect(await fixture.store.load(for: subjectB) == .loaded(second))
    }

    @Test func allAppOwnedPurgeRemovesDeviceAndEveryAccountPreference() async throws {
        let fixture = try makeFixture()
        try await fixture.store.save(.defaultDeny, for: .deviceLocal)
        try await fixture.store.save(
            AccountPrivacyPreferences(receiptAnalysisConsent: grant(version: 1, time: 100)),
            for: subjectA
        )
        try await fixture.store.save(
            AccountPrivacyPreferences(wardrobeStylingConsent: grant(version: 1, time: 200)),
            for: subjectB
        )
        let unrelatedKey = "unrelated.\(UUID().uuidString)"
        await fixture.store.replaceUnrelatedValueForTesting("keep", key: unrelatedKey)

        #expect(await fixture.store.removeAllAppOwnedPreferencesAndVerify())

        #expect(await fixture.store.load(for: .deviceLocal) == .loaded(.defaultDeny))
        #expect(await fixture.store.load(for: subjectA) == .loaded(.defaultDeny))
        #expect(await fixture.store.load(for: subjectB) == .loaded(.defaultDeny))
        #expect(await fixture.store.unrelatedValueForTesting(key: unrelatedKey) == "keep")
    }

    @Test func corruptDataIsUnavailableAndGateFailsClosed() async throws {
        let fixture = try makeFixture()
        await fixture.store.replaceRawDataForTesting(Data("not-json".utf8), for: subjectA)

        let result = await fixture.store.load(for: subjectA)

        #expect(result == .unavailable(.corruptData))
        let gatekeeper = PrivacyGatekeeper()
        for capability in PrivacyCapability.allCases {
            #expect(gatekeeper.decision(for: capability, loadResult: result)
                == .denied(.preferencesUnavailable))
        }
    }

    @Test func unsupportedStoredFormatIsUnavailableAndGateFailsClosed() async throws {
        let fixture = try makeFixture()
        let unsupported = AccountPrivacyPreferences(
            formatVersion: AccountPrivacyPreferences.currentFormatVersion + 1,
            receiptAnalysisConsent: grant(version: 1, time: 100),
            wardrobeStylingConsent: grant(version: 1, time: 100),
            backgroundReceiptSyncEnabled: true,
            dailyReminderEnabled: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        await fixture.store.replaceRawDataForTesting(try encoder.encode(unsupported), for: subjectA)

        let result = await fixture.store.load(for: subjectA)

        #expect(result == .unavailable(.unsupportedFormatVersion(
            found: AccountPrivacyPreferences.currentFormatVersion + 1,
            supported: AccountPrivacyPreferences.currentFormatVersion
        )))
        for capability in PrivacyCapability.allCases {
            #expect(PrivacyGatekeeper().decision(for: capability, loadResult: result)
                == .denied(.preferencesUnavailable))
        }
    }

    @Test func savingUnsupportedFormatIsRejectedWithoutOverwritingCurrentData() async throws {
        let fixture = try makeFixture()
        let current = AccountPrivacyPreferences(
            receiptAnalysisConsent: grant(version: 1, time: 100)
        )
        try await fixture.store.save(current, for: subjectA)
        let unsupported = AccountPrivacyPreferences(
            formatVersion: AccountPrivacyPreferences.currentFormatVersion + 1,
            wardrobeStylingConsent: grant(version: 1, time: 200)
        )

        await #expect(throws: PrivacyPreferencesStoreWriteError.self) {
            try await fixture.store.save(unsupported, for: subjectA)
        }

        #expect(await fixture.store.load(for: subjectA) == .loaded(current))
    }

    private struct Fixture {
        let keyPrefix: String
        let store: UserDefaultsPrivacyPreferencesStore
    }

    private func makeFixture() throws -> Fixture {
        let suiteName = "PrivacyPreferencesStoreTests.\(UUID().uuidString)"
        let keyPrefix = "tests.privacy.\(UUID().uuidString)"
        return Fixture(
            keyPrefix: keyPrefix,
            store: UserDefaultsPrivacyPreferencesStore(suiteName: suiteName, keyPrefix: keyPrefix)
        )
    }

    private func grant(version: Int, time: TimeInterval) -> PrivacyConsentGrant {
        PrivacyConsentGrant(
            noticeVersion: PrivacyNoticeVersion(rawValue: version),
            grantedAt: Date(timeIntervalSince1970: time)
        )
    }
}

private extension PrivacyPreferencesLoadResult {
    var preferences: AccountPrivacyPreferences? {
        guard case .loaded(let preferences) = self else { return nil }
        return preferences
    }
}
