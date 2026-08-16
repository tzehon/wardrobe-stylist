import Foundation

/// The minimum restored Google session needed by a headless receipt import.
/// The identity is copied out of GoogleSignIn and the Gmail client remains
/// structurally GET-only.
struct BackgroundSyncSession: Sendable {
    let identity: GoogleSignInIdentity
    let gmailClient: GmailReadOnlyClient

    /// Reject missing/blank provider identifiers rather than accidentally
    /// falling back to device-wide consent for an account-scoped operation.
    var privacySubjectID: PrivacySubjectID? {
        let stableID = identity.stableUserID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stableID.isEmpty else { return nil }
        return .external(stableID)
    }
}

/// Testable policy boundary shared by app-background scheduling and an actual
/// `BGProcessingTask` execution. Every entry and exit checks the external Google
/// subject's current privacy choice; missing identity or unavailable preferences
/// fail closed and cancel any pending request.
@MainActor
final class BackgroundSyncController {
    typealias RestoreSession = @MainActor () async throws -> BackgroundSyncSession
    typealias RunSync = @MainActor (BackgroundSyncSession, PrivacySubjectID) async -> Bool

    private let restoreSession: RestoreSession
    private let privacyGate: any PrivacyGateChecking
    private let runSync: RunSync
    private let scheduleNext: @MainActor () throws -> Void
    private let cancelPending: @MainActor () -> Void

    init(
        restoreSession: @escaping RestoreSession,
        privacyGate: any PrivacyGateChecking,
        runSync: @escaping RunSync,
        scheduleNext: @escaping @MainActor () throws -> Void = {
            try ReceiptSyncScheduler.schedule()
        },
        cancelPending: @escaping @MainActor () -> Void = {
            ReceiptSyncScheduler.cancel()
        }
    ) {
        self.restoreSession = restoreSession
        self.privacyGate = privacyGate
        self.runSync = runSync
        self.scheduleNext = scheduleNext
        self.cancelPending = cancelPending
    }

    /// Called when the app enters the background. This never submits a task on
    /// the strength of a device-local/default preference: a restored, scoped,
    /// stable Google identity and current background-import permission are both
    /// mandatory at the scheduling boundary.
    @discardableResult
    func reconcilePendingRequest() async -> Bool {
        guard await allowedSession() != nil else {
            cancelPending()
            return false
        }

        guard !Task.isCancelled else {
            cancelPending()
            return false
        }
        do {
            try scheduleNext()
            return true
        } catch {
            cancelPending()
            return false
        }
    }

    /// Executes a launched background task. The privacy gate runs before the
    /// sync closure can create a backend client or issue Gmail requests, and is
    /// checked again before extending the scheduling chain.
    func performBackgroundSync() async -> Bool {
        guard let (session, subjectID) = await allowedSession() else {
            cancelPending()
            return false
        }

        let syncSucceeded = await runSync(session, subjectID)
        guard !Task.isCancelled else {
            cancelPending()
            return false
        }

        let postSyncDecision = await privacyGate.decision(
            for: .backgroundReceiptImport,
            subjectID: subjectID
        )
        guard !Task.isCancelled, postSyncDecision.isAllowed else {
            cancelPending()
            return false
        }

        do {
            // A transient sync failure should not permanently break the chain,
            // but it is still reported to BackgroundTasks as unsuccessful.
            try scheduleNext()
            return syncSucceeded
        } catch {
            cancelPending()
            return false
        }
    }

    private func allowedSession() async -> (BackgroundSyncSession, PrivacySubjectID)? {
        guard !Task.isCancelled else { return nil }

        let session: BackgroundSyncSession
        do {
            session = try await restoreSession()
        } catch {
            return nil
        }
        guard !Task.isCancelled, let subjectID = session.privacySubjectID else {
            return nil
        }

        let decision = await privacyGate.decision(
            for: .backgroundReceiptImport,
            subjectID: subjectID
        )
        guard !Task.isCancelled, decision.isAllowed else { return nil }
        return (session, subjectID)
    }
}
