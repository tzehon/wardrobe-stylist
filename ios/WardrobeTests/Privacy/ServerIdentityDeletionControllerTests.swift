import Foundation
import Testing

@testable import Wardrobe

struct ServerIdentityDeletionControllerTests {
    @Test func confirmationKeepsAllThreeDestructiveOperationsDistinct() {
        let confirmation = ServerIdentityDeletionConfirmation()

        #expect(confirmation.title == "Delete server security data?")
        #expect(confirmation.destructiveActionTitle == "Delete Server Security Data")
        #expect(confirmation.message.contains("App Attest"))
        #expect(confirmation.message.contains("does not delete your wardrobe"))
        #expect(confirmation.message.contains("does not") && confirmation.message.contains("disconnect Google"))
        #expect(confirmation.message.contains("new anonymous identity"))
        #expect(confirmation.message.contains("14 days"))
    }

    @MainActor
    @Test func verifiedDeletionPublishesSuccess() async {
        let deletion = FakeServerIdentityDeletion(result: .success(.deleted))
        let controller = ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: ReceiptSyncActivityController()
        )

        let succeeded = await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        )

        #expect(succeeded)
        #expect(controller.state == .succeeded(.deleted))
        #expect(await deletion.callCount == 1)
    }

    @MainActor
    @Test func noVerifiableIdentityIsACompletedInformationalResult() async {
        let deletion = FakeServerIdentityDeletion(result: .success(.noVerifiableIdentity))
        let controller = ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: ReceiptSyncActivityController()
        )

        let completed = await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        )

        #expect(completed)
        #expect(controller.state == .succeeded(.noVerifiableIdentity))
    }

    @MainActor
    @Test func safeAuthorizationFailureIsShownWithoutTechnicalDetails() async {
        let deletion = FakeServerIdentityDeletion(
            result: .failure(AppAttestAuthorizationError.network(.notConnectedToInternet))
        )
        let controller = ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: ReceiptSyncActivityController()
        )

        let succeeded = await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        )

        #expect(!succeeded)
        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected a safe deletion failure")
            return
        }
        #expect(failure.errorDescription == "Couldn’t Delete Server Security Data")
        #expect(failure.recoverySuggestion?.contains("offline") == true)
        #expect(!failure.recoverySuggestion!.contains("NSURLError"))
    }

    @MainActor
    @Test func unsupportedDeletionStatesThatServerDataWasNotDeleted() async {
        let deletion = FakeServerIdentityDeletion(
            result: .failure(AppAttestAuthorizationError.unsupportedDevice)
        )
        let controller = ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: ReceiptSyncActivityController()
        )

        let succeeded = await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        )

        #expect(!succeeded)
        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected an unsupported-device deletion failure")
            return
        }
        #expect(failure.recoverySuggestion?.contains("was not deleted") == true)
        #expect(failure.recoverySuggestion?.contains("90 days") == true)
    }

    @MainActor
    @Test func occupiedPrivacyWindowFailsWithoutCallingTheServer() async {
        let syncActivity = ReceiptSyncActivityController()
        let occupied = AsyncLatch()
        let release = AsyncLatch()
        let holder = Task { @MainActor in
            await syncActivity.withQuiesced {
                await occupied.open()
                await release.wait()
            }
        }
        await occupied.wait()

        let deletion = FakeServerIdentityDeletion(result: .success(.deleted))
        let controller = ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: syncActivity
        )
        let succeeded = await controller.delete(
            confirmedBy: ServerIdentityDeletionConfirmation().confirm()
        )

        #expect(!succeeded)
        #expect(await deletion.callCount == 0)
        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected a no-sync-window failure")
            await release.open()
            await holder.value
            return
        }
        #expect(failure.recoverySuggestion?.contains("Receipt import") == true)
        await release.open()
        await holder.value
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
        pending.forEach { $0.resume() }
    }
}
