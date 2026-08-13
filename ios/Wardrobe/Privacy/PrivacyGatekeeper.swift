import Foundation

enum PrivacyCapability: CaseIterable, Sendable {
    case manualReceiptImport
    case backgroundReceiptImport
    case aiStyling
    case dailyReminder
}

enum PrivacyGateDenial: Error, Equatable, Sendable {
    case receiptConsentRequired
    case stylingConsentRequired
    case backgroundReceiptSyncDisabled
    case dailyReminderDisabled
    case preferencesUnavailable
}

enum PrivacyGateDecision: Equatable, Sendable {
    case allowed
    case denied(PrivacyGateDenial)

    var isAllowed: Bool {
        self == .allowed
    }
}

protocol PrivacyGateChecking: Sendable {
    func decision(
        for capability: PrivacyCapability,
        subjectID: PrivacySubjectID
    ) async -> PrivacyGateDecision
}

/// Pure policy evaluator. It performs no storage, UI, authentication, or action
/// side effects, so every protected call site can apply the same deterministic
/// rules after loading preferences for its active `PrivacySubjectID`.
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

        switch capability {
        case .manualReceiptImport:
            return hasCurrentReceiptConsent(preferences)
                ? .allowed
                : .denied(.receiptConsentRequired)

        case .backgroundReceiptImport:
            guard hasCurrentReceiptConsent(preferences) else {
                return .denied(.receiptConsentRequired)
            }
            return preferences.backgroundReceiptSyncEnabled
                ? .allowed
                : .denied(.backgroundReceiptSyncDisabled)

        case .aiStyling:
            return hasCurrentStylingConsent(preferences)
                ? .allowed
                : .denied(.stylingConsentRequired)

        case .dailyReminder:
            guard hasCurrentStylingConsent(preferences) else {
                return .denied(.stylingConsentRequired)
            }
            return preferences.dailyReminderEnabled
                ? .allowed
                : .denied(.dailyReminderDisabled)
        }
    }

    private func hasCurrentReceiptConsent(_ preferences: AccountPrivacyPreferences) -> Bool {
        preferences.receiptAnalysisConsent?.noticeVersion == requiredNotices.receiptAnalysis
    }

    private func hasCurrentStylingConsent(_ preferences: AccountPrivacyPreferences) -> Bool {
        preferences.wardrobeStylingConsent?.noticeVersion == requiredNotices.wardrobeStyling
    }
}

/// Production policy adapter: loads the active subject's persisted choices, then
/// evaluates them using the same pure, version-aware rules as unit tests.
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
        let preferences = await store.load(for: subjectID)
        return policy.decision(for: capability, loadResult: preferences)
    }
}
