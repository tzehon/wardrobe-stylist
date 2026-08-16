import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct ReceiptSyncActivityControllerTests {
    @Test func cancelWaitsForOperationToObserveCancellationAndFinish() async {
        let controller = ReceiptSyncActivityController()
        let probe = CancellationProbe()
        let started = AsyncLatch()
        let run = Task { @MainActor in
            await controller.run {
                await started.open()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch is CancellationError {
                    await probe.recordCancellation()
                } catch {
                    Issue.record("Unexpected sleep error: \(error)")
                }
                await probe.recordFinished()
            }
        }
        await started.wait()
        #expect(controller.isRunning)

        #expect(await controller.cancelAndWait())
        await run.value

        #expect(await probe.wasCancelled())
        #expect(await probe.didFinish())
        #expect(controller.isRunning == false)
    }

    @Test func idleCancellationIsImmediatelySuccessful() async {
        let controller = ReceiptSyncActivityController()
        #expect(await controller.cancelAndWait())
        #expect(controller.isRunning == false)
    }

    @Test func secondRunIsIgnoredWhileFirstIsActive() async {
        let controller = ReceiptSyncActivityController()
        let started = AsyncLatch()
        let release = AsyncLatch()
        let probe = CancellationProbe()
        let first = Task { @MainActor in
            await controller.run {
                await started.open()
                await release.wait()
                await probe.recordFinished()
            }
        }
        await started.wait()

        await controller.run {
            Issue.record("A second concurrent sync must not start")
        }
        await release.open()
        await first.value

        #expect(await probe.didFinish())
        #expect(controller.isRunning == false)
    }

    @Test func resultBearingRunReturnsTheOperationResult() async {
        let controller = ReceiptSyncActivityController()

        let result = await controller.runReturning { 42 }

        #expect(result == 42)
        #expect(controller.isRunning == false)
    }

    @Test func concurrentResultBearingRunReturnsNilWithoutStarting() async {
        let controller = ReceiptSyncActivityController()
        let started = AsyncLatch()
        let release = AsyncLatch()
        let first = Task { @MainActor in
            await controller.runReturning {
                await started.open()
                await release.wait()
                return true
            }
        }
        await started.wait()

        let rejected = await controller.runReturning {
            Issue.record("A second concurrent sync must not start")
            return false
        }
        #expect(rejected == nil)

        await release.open()
        #expect(await first.value == true)
        #expect(controller.isRunning == false)
    }

    @Test func cancellingTheRunCallerPropagatesIntoTheOwnedOperation() async {
        let controller = ReceiptSyncActivityController()
        let started = AsyncLatch()
        let probe = CancellationProbe()
        let run = Task { @MainActor in
            await controller.run {
                await started.open()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch is CancellationError {
                    await probe.recordCancellation()
                } catch {
                    Issue.record("Unexpected sleep error: \(error)")
                }
            }
        }
        await started.wait()

        run.cancel()
        await run.value

        #expect(await probe.wasCancelled())
        #expect(controller.isRunning == false)
    }

    @Test func quiescenceCancelsCurrentWorkAndRejectsRunsUntilCriticalOperationEnds() async {
        let controller = ReceiptSyncActivityController()
        let syncStarted = AsyncLatch()
        let criticalStarted = AsyncLatch()
        let releaseCritical = AsyncLatch()
        let probe = CancellationProbe()
        let sync = Task { @MainActor in
            await controller.run {
                await syncStarted.open()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch is CancellationError {
                    await probe.recordCancellation()
                } catch {
                    Issue.record("Unexpected sleep error: \(error)")
                }
            }
        }
        await syncStarted.wait()

        let critical = Task { @MainActor in
            await controller.withQuiesced {
                await criticalStarted.open()
                await releaseCritical.wait()
                return "finished"
            }
        }
        await criticalStarted.wait()

        #expect(controller.isQuiesced)
        #expect(controller.isRunning == false)
        #expect(await probe.wasCancelled())
        let rejected = await controller.runReturning {
            Issue.record("Sync must remain blocked for the full critical operation")
            return true
        }
        #expect(rejected == nil)

        await releaseCritical.open()
        #expect(await critical.value == "finished")
        await sync.value
        #expect(controller.isQuiesced == false)
        #expect(await controller.runReturning { true } == true)
    }

    private actor CancellationProbe {
        private var cancelled = false
        private var finished = false
        func recordCancellation() { cancelled = true }
        func recordFinished() { finished = true }
        func wasCancelled() -> Bool { cancelled }
        func didFinish() -> Bool { finished }
    }

    private actor AsyncLatch {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func open() {
            guard !isOpen else { return }
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            for waiter in pending { waiter.resume() }
        }
    }
}
