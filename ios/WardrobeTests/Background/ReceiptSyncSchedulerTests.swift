import BackgroundTasks
import Foundation
import Testing

@testable import Wardrobe

struct ReceiptSyncSchedulerTests {

    private struct StubError: Error {}

    private final class FakeSubmitter: BackgroundTaskSubmitting {
        var submitted: [BGTaskRequest] = []
        var error: Error?

        func submit(_ request: BGTaskRequest) throws {
            if let error { throw error }
            submitted.append(request)
        }
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func requestCarriesIdentifierAndConstraints() {
        let request = ReceiptSyncScheduler.makeRequest(now: now, interval: 3600)

        #expect(request.identifier == ReceiptSyncScheduler.taskIdentifier)
        #expect(request.requiresNetworkConnectivity)
        #expect(request.requiresExternalPower == false)
        #expect(request.earliestBeginDate == now.addingTimeInterval(3600))
    }

    @Test func defaultIntervalIsRoughlyDaily() {
        let request = ReceiptSyncScheduler.makeRequest(now: now)
        #expect(request.earliestBeginDate == now.addingTimeInterval(24 * 60 * 60))
    }

    @Test func scheduleSubmitsOneMatchingRequest() throws {
        let submitter = FakeSubmitter()
        try ReceiptSyncScheduler.schedule(using: submitter, now: now)

        #expect(submitter.submitted.count == 1)
        #expect(submitter.submitted.first?.identifier == ReceiptSyncScheduler.taskIdentifier)
    }

    @Test func schedulePropagatesSubmissionError() {
        let submitter = FakeSubmitter()
        submitter.error = StubError()

        #expect(throws: StubError.self) {
            try ReceiptSyncScheduler.schedule(using: submitter, now: now)
        }
        #expect(submitter.submitted.isEmpty)
    }
}
