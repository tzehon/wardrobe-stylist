import BackgroundTasks
import Foundation
import SwiftData

/// Runs the receipt sync from a `BGProcessingTask` launch handler. Rebuilds the
/// dependency graph the same way `ContentView.runSync` does, but headless: it
/// silently restores the Gmail session from the Keychain (no UI) and bails if the
/// user isn't signed in or the backend isn't configured.
///
/// Device-only in practice — it depends on the BackgroundTasks daemon and a
/// GoogleSignIn Keychain session, neither of which exists in the simulator/test
/// host — so it isn't unit-tested. The scheduling logic that *is* testable lives
/// in `ReceiptSyncScheduler`.
@MainActor
enum BackgroundSyncRunner {

    /// Background runs are cheaper than a manual sync: the user isn't watching and
    /// we want to finish comfortably inside the OS-granted window.
    static let maxMessages = 50

    static func run(task: BGProcessingTask, container: ModelContainer) async {
        // Reschedule first: even if this run is killed mid-sync, the daily chain
        // survives. Submitting with the same identifier replaces the pending one.
        try? ReceiptSyncScheduler.schedule()

        let work = Task { @MainActor in await performSync(container: container) }
        // Must be @Sendable: iOS invokes the expiration handler on BGTaskScheduler's
        // private queue, and a plain closure formed in this @MainActor context would
        // inherit main-actor isolation and trap on entry (same crash class as the
        // registration handler — see WardrobeApp.registerBackgroundSync).
        task.expirationHandler = { @Sendable in work.cancel() }
        let success = await work.value
        task.setTaskCompleted(success: success)
    }

    private static func performSync(container: ModelContainer) async -> Bool {
        let session = GmailSession()
        await session.restorePreviousSignIn()
        guard let gmailClient = session.client else { return false }
        guard let config = try? BackendConfig.load() else { return false }

        let pipeline = ReceiptPipeline(
            gmailClient: gmailClient,
            extractClient: ExtractClient(
                baseURL: config.baseURL,
                deviceToken: config.deviceToken
            ),
            modelContext: container.mainContext
        )
        await pipeline.sync(maxMessages: maxMessages)
        if case .failed = pipeline.state { return false }
        return true
    }
}
