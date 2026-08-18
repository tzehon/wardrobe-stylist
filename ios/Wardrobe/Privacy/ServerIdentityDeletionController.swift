import Foundation
import Observation

struct ConfirmedServerIdentityDeletion: Sendable {
    fileprivate init() {}
}

struct ServerIdentityDeletionConfirmation: Equatable, Sendable {
    let title = "Delete server security data?"
    let message = "This uses App Attest to prove control of this installation, then deletes its anonymous server identity and active AI sessions. It does not delete your wardrobe on this iPhone or disconnect Google. Remote AI will create a new anonymous identity the next time you use it. The server’s approved snapshot-retention limit is 14 days."
    let destructiveActionTitle = "Delete Server Security Data"

    func confirm() -> ConfirmedServerIdentityDeletion {
        ConfirmedServerIdentityDeletion()
    }
}

struct ServerIdentityDeletionFailure: Error, Equatable, LocalizedError, Sendable {
    let message: String

    var errorDescription: String? { "Couldn’t Delete Server Security Data" }
    var recoverySuggestion: String? { message }
}

@MainActor
@Observable
final class ServerIdentityDeletionController {
    enum State: Equatable {
        case idle
        case deleting
        case succeeded(ServerIdentityDeletionResult)
        case failed(ServerIdentityDeletionFailure)
    }

    private(set) var state: State = .idle

    private let deletion: any ServerIdentityDeleting
    private let syncActivity: ReceiptSyncActivityController

    init(
        deletion: any ServerIdentityDeleting,
        syncActivity: ReceiptSyncActivityController
    ) {
        self.deletion = deletion
        self.syncActivity = syncActivity
    }

    @discardableResult
    func delete(confirmedBy confirmation: ConfirmedServerIdentityDeletion) async -> Bool {
        _ = confirmation
        guard state != .deleting else { return false }
        state = .deleting
        let operation: Result<ServerIdentityDeletionResult, Error>? =
            await syncActivity.withQuiesced {
                do {
                    return .success(try await self.deletion.deleteServerIdentity())
                } catch {
                    return .failure(error)
                }
            }
        guard let operation else {
            return fail("Receipt import is still stopping. Wait a moment, then try again.")
        }
        switch operation {
        case .success(let result):
            state = .succeeded(result)
            return true
        case .failure(AppAttestAuthorizationError.unsupportedDevice):
            return fail("This device cannot produce the App Attest proof required for deletion, so server data was not deleted. Any inaccessible identity expires after 90 days of inactivity.")
        case .failure(let error as AppAttestAuthorizationError):
            return fail(error.localizedDescription)
        case .failure:
            return fail("Server security data could not be deleted. Please try again.")
        }
    }

    func resetResult() {
        guard state != .deleting else { return }
        state = .idle
    }

    @discardableResult
    private func fail(_ message: String) -> Bool {
        state = .failed(ServerIdentityDeletionFailure(message: message))
        return false
    }
}
