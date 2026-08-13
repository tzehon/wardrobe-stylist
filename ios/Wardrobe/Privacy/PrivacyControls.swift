import Foundation
import Observation

enum PrivacyControlsFailure: Error, Equatable, Sendable {
    case preferencesUnavailable
    case receiptConsentRequired
    case stylingConsentRequired
    case saveFailed

    var userMessage: String {
        switch self {
        case .preferencesUnavailable:
            "Your privacy choices couldn’t be loaded. Protected features remain off."
        case .receiptConsentRequired:
            "Review and allow receipt analysis before enabling background import."
        case .stylingConsentRequired:
            "Review and allow AI styling before enabling reminders."
        case .saveFailed:
            "Your privacy choice couldn’t be saved. Nothing was enabled. Please try again."
        }
    }
}

/// Main-actor state for one privacy subject. It owns only persisted choices;
/// notification/background side effects are coordinated separately so a toggle
/// can compensate safely if scheduling fails.
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

    func grantReceiptAnalysis() async throws {
        try await update { preferences in
            preferences.receiptAnalysisConsent = PrivacyConsentGrant(
                noticeVersion: requiredNotices.receiptAnalysis,
                grantedAt: now()
            )
        }
    }

    func withdrawReceiptAnalysis() async throws {
        try await update { preferences in
            preferences.receiptAnalysisConsent = nil
            preferences.backgroundReceiptSyncEnabled = false
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

    /// Persists the preference only. The automation coordinator must schedule
    /// first and call this with true only after scheduling succeeds.
    func setBackgroundReceiptSyncEnabled(_ isEnabled: Bool) async throws {
        try await update { preferences in
            if isEnabled,
               preferences.receiptAnalysisConsent?.noticeVersion != requiredNotices.receiptAnalysis {
                throw PrivacyControlsFailure.receiptConsentRequired
            }
            preferences.backgroundReceiptSyncEnabled = isEnabled
        }
    }

    /// Persists the preference only. Notification authorization/scheduling is
    /// handled before this is set true; disabling is persisted before removal.
    func setDailyReminderEnabled(_ isEnabled: Bool) async throws {
        try await update { preferences in
            if isEnabled,
               preferences.wardrobeStylingConsent?.noticeVersion != requiredNotices.wardrobeStyling {
                throw PrivacyControlsFailure.stylingConsentRequired
            }
            preferences.dailyReminderEnabled = isEnabled
        }
    }

    /// Persists both automation switches in one write. Sign-out and privacy
    /// reconciliation use this before removing their pending system work.
    func disableAutomations() async throws {
        try await update { preferences in
            preferences.backgroundReceiptSyncEnabled = false
            preferences.dailyReminderEnabled = false
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
            // Keep the last known persisted state rather than showing an
            // optimistic choice that failed to save.
            state = .loaded(current)
            throw PrivacyControlsFailure.saveFailed
        }
    }
}
