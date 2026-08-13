import BackgroundTasks
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    @State private var storeController: PersistentStoreController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let storeController = PersistentStoreController()
        _storeController = State(initialValue: storeController)
        Self.registerBackgroundSync(storeController: storeController)
    }

    var body: some Scene {
        WindowGroup {
            launchContent
        }
        .onChange(of: scenePhase) { _, phase in
            // Reconcile rather than scheduling blindly. The controller silently
            // restores a valid Google identity and checks that subject's current
            // receipt consent + background toggle before it submits any work.
            if phase == .background {
                guard let container = storeController.container else {
                    ReceiptSyncScheduler.cancel()
                    return
                }
                Task { @MainActor in
                    await BackgroundSyncRunner.reconcilePendingRequest(container: container)
                }
            }
        }
    }

    @ViewBuilder
    private var launchContent: some View {
        switch storeController.state {
        case .loading:
            ProgressView("Opening your wardrobe…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let container):
            ContentView()
                .onOpenURL { url in
                    // OAuth callback: route URL-scheme redirects to the GoogleSignIn SDK
                    // so it can complete the sign-in flow.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
                .modelContainer(container)
        case .failed:
            PersistentStoreErrorView(retry: storeController.retry)
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
    private static func registerBackgroundSync(storeController: PersistentStoreController) {
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
                guard let container = storeController.container else {
                    transferredTask.setTaskCompleted(success: false)
                    return
                }
                await BackgroundSyncRunner.run(task: transferredTask, container: container)
            }
        }
    }
}
