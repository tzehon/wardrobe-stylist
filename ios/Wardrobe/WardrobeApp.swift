import BackgroundTasks
import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    @State private var storeController: PersistentStoreController
    @State private var demoMode: DemoModeController
    @Environment(\.scenePhase) private var scenePhase

    private static let isReviewerDemoLaunch = DemoLaunchPolicy.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )

    init() {
        DailyReminderNotificationRouter.shared.install()
        // A command-line reviewer Demo must be able to launch even when the
        // user's real store is corrupt or needs migration. Defer opening the
        // production store until the reviewer explicitly exits the isolated
        // in-memory tour.
        let storeController = PersistentStoreController(
            automaticallyLoad: !Self.isReviewerDemoLaunch
        )
        let demoMode = DemoModeController(
            automaticallyEnter: Self.isReviewerDemoLaunch
        )
        _storeController = State(initialValue: storeController)
        _demoMode = State(initialValue: demoMode)
        if !Self.isReviewerDemoLaunch {
            Self.registerBackgroundSync(
                storeController: storeController,
                demoMode: demoMode
            )
        }
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
                guard !demoMode.isActive else { return }
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
        if let demoSession = demoMode.session {
            // Intentionally outside the production model-container hierarchy.
            // The reviewer-launch root receives only its disposable in-memory
            // store, so exiting cannot transiently render production queries
            // before PersistentStoreController has opened the real wardrobe.
            DemoModeRootView(
                session: demoSession,
                onReset: { _ = demoMode.reset() },
                onExit: demoMode.exit
            )
            .id(ObjectIdentifier(demoSession))
        } else if Self.isReviewerDemoLaunch,
                  !storeController.hasStartedLoading,
                  demoMode.failure != nil {
            ContentUnavailableView {
                Label("Demo unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(DemoModeFailure.userMessage)
            } actions: {
                Button("Try Demo Again") {
                    demoMode.clearFailure()
                    _ = demoMode.enter()
                }
                .buttonStyle(.borderedProminent)

                Button("Continue to My Wardrobe") {
                    demoMode.clearFailure()
                    storeController.beginProductionStoreAfterReviewerDemo()
                }
                .buttonStyle(.bordered)
            }
        } else {
            switch storeController.state {
            case .loading:
                ProgressView("Opening your wardrobe…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        if Self.isReviewerDemoLaunch {
                            storeController.beginProductionStoreAfterReviewerDemo()
                        } else {
                            storeController.loadIfNeeded()
                        }
                    }
            case .ready(let container):
                ContentView(demoMode: demoMode)
                    .modelContainer(container)
            case .failed:
                PersistentStoreErrorView(retry: storeController.retry)
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
    private static func registerBackgroundSync(
        storeController: PersistentStoreController,
        demoMode: DemoModeController
    ) {
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
                guard !demoMode.isActive else {
                    // A task scheduled before entering Demo Mode may still be
                    // delivered by the OS. Complete it without restoring Google
                    // identity, reaching Gmail/backend, or scheduling another.
                    transferredTask.setTaskCompleted(success: true)
                    return
                }
                guard let container = storeController.container else {
                    transferredTask.setTaskCompleted(success: false)
                    return
                }
                await BackgroundSyncRunner.run(task: transferredTask, container: container)
            }
        }
    }
}
