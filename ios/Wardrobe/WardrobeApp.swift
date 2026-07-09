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
    private func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: ReceiptSyncScheduler.taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let container = self.container
            Task { await BackgroundSyncRunner.run(task: processingTask, container: container) }
        }
    }
}
