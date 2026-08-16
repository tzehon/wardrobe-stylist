import BackgroundTasks
import Foundation
import SwiftData

/// Runs the receipt sync from a `BGProcessingTask` launch handler. Rebuilds the
/// dependency graph the same way the Settings import does, but headless. The
/// testable `BackgroundSyncController` restores and validates the external Google
/// subject, checks current consent before any Gmail/backend work, and re-checks
/// permission before it extends the scheduling chain.
///
/// The thin `BGProcessingTask` adapter is device-only; all policy and cancellation
/// behavior beneath it is covered through `BackgroundSyncController` and pipeline
/// tests in the simulator.
@MainActor
enum BackgroundSyncRunner {

    /// Background runs are cheaper than a manual sync: the user isn't watching and
    /// we want to finish comfortably inside the OS-granted window.
    static let maxMessages = 50

    static func run(task: BGProcessingTask, container: ModelContainer) async {
        let controller = makeController(container: container)
        let work = Task { @MainActor in
            await ReceiptSyncActivityController.shared.runReturning {
                await controller.performBackgroundSync()
            } ?? false
        }
        // Must be @Sendable: iOS invokes the expiration handler on BGTaskScheduler's
        // private queue, and a plain closure formed in this @MainActor context would
        // inherit main-actor isolation and trap on entry (same crash class as the
        // registration handler — see WardrobeApp.registerBackgroundSync).
        task.expirationHandler = { @Sendable in work.cancel() }
        let success = await work.value
        task.setTaskCompleted(success: success)
    }

    /// Reconciles the pending request when the app enters the background. A
    /// restored external Google subject with current receipt consent and an
    /// enabled background toggle is required; every other state cancels.
    @discardableResult
    static func reconcilePendingRequest(container: ModelContainer) async -> Bool {
        await ReceiptSyncActivityController.shared.runReturning {
            await makeController(container: container).reconcilePendingRequest()
        } ?? false
    }

    private static func makeController(container: ModelContainer) -> BackgroundSyncController {
        BackgroundSyncController(
            restoreSession: {
                let session = GmailSession()
                await session.restorePreviousSignIn()
                guard let identity = session.identity, let gmailClient = session.client else {
                    throw BackgroundSessionFailure.notSignedIn
                }
                return BackgroundSyncSession(identity: identity, gmailClient: gmailClient)
            },
            privacyGate: StoredPrivacyGatekeeper(),
            runSync: { session, subjectID in
                guard !Task.isCancelled else { return false }
                guard let config = try? BackendConfig.load() else { return false }

                let pipeline = ReceiptPipeline(
                    gmailClient: session.gmailClient,
                    extractClient: ExtractClient(
                        baseURL: config.baseURL,
                        deviceToken: config.deviceToken
                    ),
                    modelContext: container.mainContext,
                    privacySubjectID: subjectID
                )
                await pipeline.sync(maxMessages: maxMessages, mode: .background)
                guard !Task.isCancelled else { return false }
                if case .complete = pipeline.state { return true }
                return false
            }
        )
    }

    private enum BackgroundSessionFailure: Error {
        case notSignedIn
    }
}
