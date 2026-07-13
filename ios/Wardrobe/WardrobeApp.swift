import BackgroundTasks
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            container = try ModelContainer(for: Item.self, Outfit.self, WearLog.self)
        } catch {
            fatalError("Failed to create the SwiftData ModelContainer: \(error)")
        }
        registerBackgroundSync()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // OAuth callback: route URL-scheme redirects to the GoogleSignIn SDK
                    // so it can complete the sign-in flow.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Schedule (or re-schedule) the next sync each time we background. The
            // OS runs it opportunistically no sooner than the earliest-begin date.
            if phase == .background {
                try? ReceiptSyncScheduler.schedule()
            }
        }
    }

    /// Registers the background receipt-sync handler. Must run before the app
    /// finishes launching, so it lives in `init`. The launch handler hands the
    /// task to `BackgroundSyncRunner`, which restores the session and syncs.
    ///
    /// The handler closure MUST be `@Sendable`. BGTaskScheduler invokes it on its
    /// own private queue; a plain closure formed here would inherit this type's
    /// @MainActor isolation (App types are MainActor-isolated), and Swift 6's
    /// runtime enforcement traps the moment the system enters it off-main
    /// (EXC_BREAKPOINT in dispatch_assert_queue_fail). That crashed every
    /// overnight sync in build 0.1.0 (2) — and never reproduced in the simulator
    /// or foreground, because the launch handler only runs when the OS actually
    /// launches the background task on device. The hop onto the main actor now
    /// happens explicitly inside, via `Task { @MainActor in … }`.
    private func registerBackgroundSync() {
        let container = container   // captured so the @Sendable closure never touches MainActor self
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: ReceiptSyncScheduler.taskIdentifier,
            using: nil
        ) { @Sendable task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // BGTask isn't Sendable, but its methods are documented thread-safe
            // and exactly one consumer touches it from here on.
            nonisolated(unsafe) let transferredTask = processingTask
            Task { @MainActor in
                await BackgroundSyncRunner.run(task: transferredTask, container: container)
            }
        }
    }
}
