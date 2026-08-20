import Foundation

enum PrivacyCapability: CaseIterable, Sendable {
    case aiStyling
    case dailyReminder
}

enum PrivacyGateDenial: Error, Equatable, Sendable {
    case stylingConsentRequired
    case dailyReminderDisabled
    case preferencesUnavailable
}

enum PrivacyGateDecision: Equatable, Sendable {
    case allowed
    case denied(PrivacyGateDenial)

    var isAllowed: Bool { self == .allowed }
}

protocol PrivacyGateChecking: Sendable {
    func decision(
        for capability: PrivacyCapability,
        subjectID: PrivacySubjectID
    ) async -> PrivacyGateDecision
}

struct PrivacyGatekeeper: Sendable {
    let requiredNotices: PrivacyNoticeRequirements

    init(requiredNotices: PrivacyNoticeRequirements = .current) {
        self.requiredNotices = requiredNotices
    }

    func decision(
        for capability: PrivacyCapability,
        loadResult: PrivacyPreferencesLoadResult
    ) -> PrivacyGateDecision {
        switch loadResult {
        case .loaded(let preferences):
            decision(for: capability, preferences: preferences)
        case .unavailable:
            .denied(.preferencesUnavailable)
        }
    }

    func decision(
        for capability: PrivacyCapability,
        preferences: AccountPrivacyPreferences
    ) -> PrivacyGateDecision {
        guard preferences.formatVersion == AccountPrivacyPreferences.currentFormatVersion else {
            return .denied(.preferencesUnavailable)
        }
        guard preferences.wardrobeStylingConsent?.noticeVersion
                == requiredNotices.wardrobeStyling else {
            return .denied(.stylingConsentRequired)
        }
        switch capability {
        case .aiStyling:
            return .allowed
        case .dailyReminder:
            return preferences.dailyReminderEnabled
                ? .allowed
                : .denied(.dailyReminderDisabled)
        }
    }
}

struct StoredPrivacyGatekeeper: PrivacyGateChecking {
    let store: any PrivacyPreferencesStoring
    let policy: PrivacyGatekeeper

    init(
        store: any PrivacyPreferencesStoring = UserDefaultsPrivacyPreferencesStore(),
        requiredNotices: PrivacyNoticeRequirements = .current
    ) {
        self.store = store
        self.policy = PrivacyGatekeeper(requiredNotices: requiredNotices)
    }

    func decision(
        for capability: PrivacyCapability,
        subjectID: PrivacySubjectID
    ) async -> PrivacyGateDecision {
        policy.decision(for: capability, loadResult: await store.load(for: subjectID))
    }
}
