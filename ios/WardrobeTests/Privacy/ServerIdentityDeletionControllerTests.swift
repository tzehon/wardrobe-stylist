import Foundation
import Testing

@testable import Wardrobe

struct ServerIdentityDeletionControllerTests {
    @Test func confirmationKeepsServerAndLocalDeletionDistinct() {
        let confirmation = ServerIdentityDeletionConfirmation()
        #expect(confirmation.title == "Delete server security data?")
        #expect(confirmation.message == "App Attest verifies this installation, then deletes its live anonymous server identity and active AI sessions. Your wardrobe stays on this device; future AI use creates a new anonymous identity. Hosting records are separate: Fly’s customer-visible proxy and platform stream lasts 7 days and may include request paths, request IDs, or client IP. Separate provider-internal logs may include source IP, with in-service retention undisclosed. Snapshots stop appearing from Fly’s customer listing after 14 days; Fly does not publish an all-copy deletion deadline.")
    }

    @MainActor
    @Test func verifiedDeletionPublishesSuccess() async {
        let deletion = FakeServerIdentityDeletion(result: .success(.deleted))
        let controller = ServerIdentityDeletionController(deletion: deletion)
        #expect(await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        ))
        #expect(controller.state == .succeeded(.deleted))
        #expect(await deletion.callCount == 1)
    }

    @MainActor
    @Test func unsupportedDeviceFailsClosedWithRetentionRecovery() async {
        let deletion = FakeServerIdentityDeletion(
            result: .failure(AppAttestAuthorizationError.unsupportedDevice)
        )
        let controller = ServerIdentityDeletionController(deletion: deletion)
        #expect(await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        ) == false)
        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected a safe failure")
            return
        }
        #expect(failure.message.contains("was not deleted"))
        #expect(failure.message.contains("90 days"))
    }
}

private actor FakeServerIdentityDeletion: ServerIdentityDeleting {
    let result: Result<ServerIdentityDeletionResult, Error>
    private(set) var callCount = 0

    init(result: Result<ServerIdentityDeletionResult, Error>) {
        self.result = result
    }

    func deleteServerIdentity() throws -> ServerIdentityDeletionResult {
        callCount += 1
        return try result.get()
    }
}
