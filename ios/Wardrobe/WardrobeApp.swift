import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    @State private var storeController: PersistentStoreController
    @State private var demoMode: DemoModeController
#if DEBUG
    @State private var connectedUITestExperience: ConnectedUITestExperience?
#endif

    private static let isReviewerDemoLaunch = DemoLaunchPolicy.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )

#if DEBUG
    private static let isConnectedUITestLaunch = ConnectedUITestLaunchPolicy.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )
    private static let isLocalUITestLaunch = LocalUITestLaunchPolicy.isRequested(
        arguments: ProcessInfo.processInfo.arguments
    )
#endif

    init() {
#if DEBUG
        if !Self.isConnectedUITestLaunch && !Self.isLocalUITestLaunch {
            DailyReminderNotificationRouter.shared.install()
        }
#else
        DailyReminderNotificationRouter.shared.install()
#endif

        let shouldLoadProductionStore: Bool
#if DEBUG
        shouldLoadProductionStore = !Self.isReviewerDemoLaunch && !Self.isConnectedUITestLaunch
#else
        shouldLoadProductionStore = !Self.isReviewerDemoLaunch
#endif

        let storeController: PersistentStoreController
#if DEBUG
        if Self.isLocalUITestLaunch {
            storeController = PersistentStoreController(loader: {
                try ModelContainerFactory.makeInMemory()
            })
        } else {
            storeController = PersistentStoreController(automaticallyLoad: shouldLoadProductionStore)
        }
#else
        storeController = PersistentStoreController(automaticallyLoad: shouldLoadProductionStore)
#endif
        let demoMode = DemoModeController(automaticallyEnter: Self.isReviewerDemoLaunch)
        _storeController = State(initialValue: storeController)
        _demoMode = State(initialValue: demoMode)
#if DEBUG
        _connectedUITestExperience = State(initialValue: Self.isConnectedUITestLaunch
            ? try? ConnectedUITestExperience()
            : nil)
#endif
    }

    var body: some Scene {
        WindowGroup { launchContent }
    }

    @ViewBuilder
    private var launchContent: some View {
#if DEBUG
        if Self.isConnectedUITestLaunch {
            if let connectedUITestExperience {
                ConnectedUITestRootView(experience: connectedUITestExperience)
            } else {
                ContentUnavailableView(
                    "Isolated UI test unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The in-memory UI-test environment could not be created.")
                )
            }
        } else {
            ordinaryLaunchContent
        }
#else
        ordinaryLaunchContent
#endif
    }

    @ViewBuilder
    private var ordinaryLaunchContent: some View {
        if let demoSession = demoMode.session {
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
                ContentView(demoMode: demoMode).modelContainer(container)
            case .failed:
                PersistentStoreErrorView(retry: storeController.retry)
            }
        }
    }
}
