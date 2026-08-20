import Foundation
import Observation

enum PrivacyControlsFailure: Error, Equatable, Sendable {
    case preferencesUnavailable
    case stylingConsentRequired
    case saveFailed

    var userMessage: String {
        switch self {
        case .preferencesUnavailable:
            "Your privacy choices couldn’t be loaded. Protected features remain off."
        case .stylingConsentRequired:
            "Review and allow AI styling before enabling reminders."
        case .saveFailed:
            "Your privacy choice couldn’t be saved. Nothing was enabled. Please try again."
        }
    }
}

@MainActor
@Observable
final class PrivacyControls {
    enum State: Equatable {
        case idle
        case loading
        case loaded(AccountPrivacyPreferences)
        case unavailable(PrivacyControlsFailure)
    }

    private(set) var state: State = .idle

    var preferences: AccountPrivacyPreferences? {
        guard case .loaded(let preferences) = state else { return nil }
        return preferences
    }

    func decision(for capability: PrivacyCapability) -> PrivacyGateDecision {
        guard let preferences else { return .denied(.preferencesUnavailable) }
        return PrivacyGatekeeper(requiredNotices: requiredNotices)
            .decision(for: capability, preferences: preferences)
    }

    private let subjectID: PrivacySubjectID
    private let store: any PrivacyPreferencesStoring
    private let requiredNotices: PrivacyNoticeRequirements
    private let now: @Sendable () -> Date

    init(
        subjectID: PrivacySubjectID,
        store: any PrivacyPreferencesStoring = UserDefaultsPrivacyPreferencesStore(),
        requiredNotices: PrivacyNoticeRequirements = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.subjectID = subjectID
        self.store = store
        self.requiredNotices = requiredNotices
        self.now = now
    }

    func load() async {
        state = .loading
        switch await store.load(for: subjectID) {
        case .loaded(let preferences):
            state = .loaded(preferences)
        case .unavailable:
            state = .unavailable(.preferencesUnavailable)
        }
    }

    func grantWardrobeStyling() async throws {
        try await update { preferences in
            preferences.wardrobeStylingConsent = PrivacyConsentGrant(
                noticeVersion: requiredNotices.wardrobeStyling,
                grantedAt: now()
            )
        }
    }

    func withdrawWardrobeStyling() async throws {
        try await update { preferences in
            preferences.wardrobeStylingConsent = nil
            preferences.dailyReminderEnabled = false
        }
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) async throws {
        try await update { preferences in
            if isEnabled,
               preferences.wardrobeStylingConsent?.noticeVersion
                    != requiredNotices.wardrobeStyling {
                throw PrivacyControlsFailure.stylingConsentRequired
            }
            preferences.dailyReminderEnabled = isEnabled
        }
    }

    private func update(
        mutation: (inout AccountPrivacyPreferences) throws -> Void
    ) async throws {
        let current: AccountPrivacyPreferences
        switch state {
        case .loaded(let preferences):
            current = preferences
        case .idle:
            switch await store.load(for: subjectID) {
            case .loaded(let preferences): current = preferences
            case .unavailable:
                state = .unavailable(.preferencesUnavailable)
                throw PrivacyControlsFailure.preferencesUnavailable
            }
        case .loading, .unavailable:
            throw PrivacyControlsFailure.preferencesUnavailable
        }

        var updated = current
        try mutation(&updated)
        do {
            try await store.save(updated, for: subjectID)
            state = .loaded(updated)
        } catch let failure as PrivacyControlsFailure {
            throw failure
        } catch {
            state = .loaded(current)
            throw PrivacyControlsFailure.saveFailed
        }
    }
}
