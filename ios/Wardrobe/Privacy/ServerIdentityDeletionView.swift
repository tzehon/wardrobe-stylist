import SwiftUI

/// A server-only privacy control. Local wardrobe deletion and Google revocation
/// intentionally remain separate Settings actions with separate confirmation.
struct ServerIdentityDeletionView: View {
    let deletion: any ServerIdentityDeleting
    let syncActivity: ReceiptSyncActivityController

    @State private var showingConfirmation = false
    @State private var controller: ServerIdentityDeletionController?

    private let confirmation = ServerIdentityDeletionConfirmation()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(confirmation.destructiveActionTitle, role: .destructive) {
                showingConfirmation = true
            }
            .disabled(isDeleting)
            .controlSize(.large)
            .accessibilityHint("Deletes only this installation’s anonymous server security record. Local data and Google access remain unchanged.")
            .accessibilityIdentifier("settings.privacy.deleteServerSecurityData")

            if isDeleting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Verifying this installation and deleting server data…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Verifying and deleting server security data")
                .accessibilityIdentifier("settings.privacy.deleteServerSecurityData.progress")
            } else if case .succeeded(let result) = controller?.state {
                status(for: result)
            }
        }
        .confirmationDialog(
            confirmation.title,
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(confirmation.destructiveActionTitle, role: .destructive) {
                Task { await deleteConfirmed() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmation.message)
        }
        .alert(
            deletionFailure?.errorDescription ?? "Couldn’t Delete Server Security Data",
            isPresented: failurePresentation,
            presenting: deletionFailure
        ) { _ in
            Button("OK", role: .cancel) { controller?.resetResult() }
        } message: { failure in
            Text(failure.recoverySuggestion ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func status(for result: ServerIdentityDeletionResult) -> some View {
        switch result {
        case .deleted:
            successLabel("Server security data deleted")
        case .alreadyAbsent:
            successLabel("Server security data was already absent")
        case .noVerifiableIdentity:
            Label(
                "This device has no server identity it can verify. Any inaccessible older identity expires after 90 days of inactivity.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("settings.privacy.deleteServerSecurityData.unavailable")
        }
    }

    private func successLabel(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .font(.footnote)
        .accessibilityLabel("Success: \(text)")
        .accessibilityIdentifier("settings.privacy.deleteServerSecurityData.success")
    }

    private var isDeleting: Bool {
        controller?.state == .deleting
    }

    private var deletionFailure: ServerIdentityDeletionFailure? {
        guard case .failed(let failure) = controller?.state else { return nil }
        return failure
    }

    private var failurePresentation: Binding<Bool> {
        Binding(
            get: { deletionFailure != nil },
            set: { isPresented in
                if !isPresented {
                    controller?.resetResult()
                }
            }
        )
    }

    @MainActor
    private func deleteConfirmed() async {
        let madeController = controller ?? ServerIdentityDeletionController(
            deletion: deletion,
            syncActivity: syncActivity
        )
        controller = madeController
        _ = await madeController.delete(confirmedBy: confirmation.confirm())
    }
}
