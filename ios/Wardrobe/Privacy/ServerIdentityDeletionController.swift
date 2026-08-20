import Foundation
import Observation

struct ConfirmedServerIdentityDeletion: Sendable {
    fileprivate init() {}
}

struct ServerIdentityDeletionConfirmation: Equatable, Sendable {
    let title = "Delete server security data?"
    let message = "App Attest verifies this installation, then deletes its live anonymous server identity and active AI sessions. Your wardrobe stays on this device; future AI use creates a new anonymous identity. Hosting records are separate: Fly’s customer-visible proxy and platform stream lasts 7 days and may include request paths, request IDs, or client IP. Separate provider-internal logs may include source IP, with in-service retention undisclosed. Snapshots stop appearing from Fly’s customer listing after 14 days; Fly does not publish an all-copy deletion deadline."
    let destructiveActionTitle = "Delete Server Security Data"

    func confirm() -> ConfirmedServerIdentityDeletion { ConfirmedServerIdentityDeletion() }
}

struct ServerIdentityDeletionFailure: Error, Equatable, LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { "Couldn’t Delete Live Server Security Record" }
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

    init(deletion: any ServerIdentityDeleting) {
        self.deletion = deletion
    }

    @discardableResult
    func delete(confirmedBy confirmation: ConfirmedServerIdentityDeletion) async -> Bool {
        _ = confirmation
        guard state != .deleting else { return false }
        state = .deleting
        do {
            state = .succeeded(try await deletion.deleteServerIdentity())
            return true
        } catch AppAttestAuthorizationError.unsupportedDevice {
            return fail("This device cannot produce the App Attest proof required for deletion, so its live server identity was not deleted. Any inaccessible live identity is removed after 90 days of inactivity. Hosting records follow separate retention.")
        } catch let error as AppAttestAuthorizationError {
            return fail(error.localizedDescription)
        } catch {
            return fail("The live server security record could not be deleted. Please try again.")
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
