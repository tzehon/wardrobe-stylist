import BackgroundTasks
import Foundation

/// Narrow seam over `BGTaskScheduler` so the scheduling logic is unit-testable
/// without the real BackgroundTasks daemon (which isn't available in the
/// simulator / test host). Production uses `BGTaskScheduler.shared`.
protocol BackgroundTaskSubmitting {
    func submit(_ request: BGTaskRequest) throws
}

extension BGTaskScheduler: BackgroundTaskSubmitting {}

/// Schedules the opportunistic background receipt sync. Pure request-building +
/// submission; the actual work runs in `BackgroundSyncRunner` from the launch
/// handler registered in `WardrobeApp`.
///
/// Uses `BGProcessingTask` rather than `BGAppRefreshTask` because a Gmail sync
/// (fetch + on-device filter + several `/extract` round-trips) can run well past
/// the ~30s an app-refresh task is granted.
enum ReceiptSyncScheduler {

    /// Must match the value in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`;
    /// `BGTaskScheduler.submit` throws at runtime if they disagree.
    static let taskIdentifier = "com.tth.Wardrobe.receiptSync"

    /// Earliest the system should consider running the next sync. The OS treats
    /// this as a floor, not a promise — it schedules opportunistically based on
    /// usage/power/network. Roughly daily.
    static let refreshInterval: TimeInterval = 24 * 60 * 60

    /// Builds the next processing-task request. `requiresNetworkConnectivity` is
    /// on because the sync is useless offline; external power is not required so
    /// it can run on battery.
    static func makeRequest(
        now: Date,
        interval: TimeInterval = refreshInterval
    ) -> BGProcessingTaskRequest {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = now.addingTimeInterval(interval)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        return request
    }

    /// Submits the next request. Safe to call repeatedly — submitting a request
    /// with an already-pending identifier replaces it. Callers should invoke this
    /// at launch and again from the task handler to keep the chain alive.
    static func schedule(
        using submitter: BackgroundTaskSubmitting = BGTaskScheduler.shared,
        now: Date = Date()
    ) throws {
        try submitter.submit(makeRequest(now: now))
    }
}
