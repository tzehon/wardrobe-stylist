import SwiftUI

struct ServerIdentityDeletionView: View {
    let deletion: any ServerIdentityDeleting

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
            .accessibilityHint("Deletes only this installation’s live anonymous server security record. Local data stays unchanged; hosting records follow separate retention.")
            .accessibilityIdentifier("settings.privacy.deleteServerSecurityData")

            if isDeleting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Verifying this installation and deleting its live server security record…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
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
            deletionFailure?.errorDescription ?? "Couldn’t Delete Live Server Security Record",
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
            successLabel("Live server security record deleted")
        case .alreadyAbsent:
            successLabel("Live server security record was already absent")
        case .noVerifiableIdentity:
            Label(
                "This device has no live server identity it can verify. Any inaccessible older live identity is removed after 90 days of inactivity. Hosting records follow separate retention.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("settings.privacy.deleteServerSecurityData.unavailable")
        }
    }

    private func successLabel(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.green)
            .accessibilityIdentifier("settings.privacy.deleteServerSecurityData.success")
    }

    private var isDeleting: Bool { controller?.state == .deleting }

    private var deletionFailure: ServerIdentityDeletionFailure? {
        guard case .failed(let failure) = controller?.state else { return nil }
        return failure
    }

    private var failurePresentation: Binding<Bool> {
        Binding(
            get: { deletionFailure != nil },
            set: { isPresented in
                if !isPresented { controller?.resetResult() }
            }
        )
    }

    @MainActor
    private func deleteConfirmed() async {
        let madeController = controller ?? ServerIdentityDeletionController(deletion: deletion)
        controller = madeController
        _ = await madeController.delete(confirmedBy: confirmation.confirm())
    }
}
