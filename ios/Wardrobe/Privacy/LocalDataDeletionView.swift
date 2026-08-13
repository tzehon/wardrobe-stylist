import SwiftData
import SwiftUI

/// Settings control for the distinct local-only deletion action. It deliberately
/// does not sign out or revoke Google; those remain separate account controls.
struct LocalDataDeletionView: View {
    let activeExternalSubject: PrivacySubjectID?
    let syncActivity: ReceiptSyncActivityController
    let onVerifiedDeletion: @MainActor () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingConfirmation = false
    @State private var coordinator: LocalDataDeletionCoordinator?
    @State private var localFailure: LocalDataDeletionFailure?

    private let confirmation = LocalDataDeletionConfirmation()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(confirmation.destructiveActionTitle, role: .destructive) {
                showingConfirmation = true
            }
            .disabled(isDeleting)
            .accessibilityHint("Permanently removes app data stored on this device. Google access remains connected.")
            .accessibilityIdentifier("settings.privacy.deleteLocalData")

            if isDeleting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Deleting and verifying local data…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.privacy.deleteLocalData.progress")
            } else if case .succeeded = coordinator?.state {
                Label("Local data deleted", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("settings.privacy.deleteLocalData.success")
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
            deletionFailure?.errorDescription ?? "Couldn’t Delete Local Data",
            isPresented: failurePresentation,
            presenting: deletionFailure
        ) { _ in
            Button("OK", role: .cancel) { coordinator?.resetResult() }
        } message: { failure in
            Text(failure.recoverySuggestion ?? "Please try again.")
        }
    }

    private var isDeleting: Bool {
        coordinator?.state == .deleting
    }

    private var deletionFailure: LocalDataDeletionFailure? {
        if let localFailure { return localFailure }
        guard case .failed(let failure) = coordinator?.state else { return nil }
        return failure
    }

    private var failurePresentation: Binding<Bool> {
        Binding(
            get: { deletionFailure != nil },
            set: { isPresented in
                if !isPresented {
                    localFailure = nil
                    coordinator?.resetResult()
                }
            }
        )
    }

    @MainActor
    private func deleteConfirmed() async {
        let madeCoordinator = coordinator ?? LocalDataDeletionCoordinator(modelContext: modelContext)
        coordinator = madeCoordinator
        let result = await syncActivity.withQuiesced {
            await madeCoordinator.delete(
                scope: .all(activeExternalSubject: activeExternalSubject),
                confirmedBy: confirmation.confirm()
            )
        }
        guard let result else {
            localFailure = LocalDataDeletionFailure(
                stage: .syncDidNotStop,
                diagnostic: "Another privacy or data operation already owns the no-sync window"
            )
            return
        }
        if result { onVerifiedDeletion() }
    }
}
