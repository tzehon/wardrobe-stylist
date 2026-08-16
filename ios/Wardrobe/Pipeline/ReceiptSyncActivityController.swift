import Foundation
import Observation

/// Owns the current receipt-import task so destructive data operations can
/// cancel it and await its terminal cancellation path before deleting models.
@MainActor
@Observable
final class ReceiptSyncActivityController {
    static let shared = ReceiptSyncActivityController()

    private(set) var isRunning = false
    private(set) var isQuiesced = false
    private var task: Task<Void, Never>?
    private var generation: UInt = 0

    /// Runs at most one import. The operation should propagate task
    /// cancellation to `ReceiptPipeline`, which publishes a cancelled state.
    @discardableResult
    func run(_ operation: @escaping @MainActor () async -> Void) async -> Bool {
        let result: Void? = await runReturning {
            await operation()
            return ()
        }
        return result != nil
    }

    /// Result-bearing variant used by background execution. A concurrent run
    /// is rejected with nil so two syncs can never share one SwiftData context.
    func runReturning<Result>(
        _ operation: @escaping @MainActor () async -> Result
    ) async -> Result? {
        guard task == nil, !isQuiesced else { return nil }
        var result: Result?
        let work = Task { @MainActor in result = await operation() }
        generation &+= 1
        let runGeneration = generation
        task = work
        isRunning = true
        await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        if generation == runGeneration {
            task = nil
            isRunning = false
        }
        return result
    }

    /// Cancellation is complete only after the operation returns. Callers may
    /// safely begin model deletion after this method reports true.
    func cancelAndWait() async -> Bool {
        guard let task else { return true }
        generation &+= 1
        task.cancel()
        await task.value
        self.task = nil
        isRunning = false
        return true
    }

    /// Holds an exclusive no-sync window for a privacy or destructive state
    /// transition. Existing work is cancelled and drained before `operation`
    /// starts, and every foreground/background run is rejected until the whole
    /// operation returns. This closes the cancel-then-new-run race that a bare
    /// `cancelAndWait` cannot close.
    func withQuiesced<Result>(
        _ operation: @escaping @MainActor () async -> Result
    ) async -> Result? {
        guard !isQuiesced else { return nil }
        isQuiesced = true
        defer { isQuiesced = false }

        generation &+= 1
        if let active = task {
            active.cancel()
            await active.value
        }
        task = nil
        isRunning = false
        return await operation()
    }
}
