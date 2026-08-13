import SwiftData
import SwiftUI

/// Explicit one-time decision for rows written before account ownership was
/// recorded. Nothing in this view runs automatically beyond counting the
/// blocked rows; assignment and deletion both require a confirmation.
struct LegacyAccountDataResolutionView: View {
    private enum PendingAction: Identifiable {
        case keep(GoogleSignInIdentity)
        case delete

        var id: String {
            switch self {
            case .keep: "keep"
            case .delete: "delete"
            }
        }
    }

    let session: GmailSession

    @Environment(\.modelContext) private var modelContext
    @State private var controller: LegacyAccountDataResolutionController?
    @State private var pendingAction: PendingAction?

    var body: some View {
        Group {
            switch controller?.state {
            case .some(.none):
                EmptyView()
            case .some(.decisionRequired(let summary)):
                decisionSection(summary)
            case .some(.failed(let error)):
                failureSection(error)
            case .some(.loading), Optional.none:
                Section("Older Imported Data") {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Checking data ownership…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            guard controller == nil else { return }
            let made = LegacyAccountDataResolutionController(
                resolver: LegacyAccountDataResolver(modelContext: modelContext)
            )
            controller = made
            made.load()
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingAction
        ) { action in
            switch action {
            case .keep(let identity):
                Button("Keep with \(identity.email)") {
                    controller?.keepWithAccount(subjectID: identity.privacySubjectID)
                }
                Button("Cancel", role: .cancel) {}
            case .delete:
                Button("Delete Older Imported Data", role: .destructive) {
                    controller?.deleteLegacyAccountData()
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: { action in
            switch action {
            case .keep(let identity):
                Text("Older imported items and outfit history will be assigned only to \(identity.email). This cannot be reassigned automatically later.")
            case .delete:
                Text("Older Gmail-imported items and unassigned outfit history will be deleted. Manual and photo items will remain.")
            }
        }
    }

    private func decisionSection(_ summary: LegacyAccountDataSummary) -> some View {
        Section {
            Label("Action required", systemImage: "person.crop.circle.badge.questionmark")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(summaryText(summary))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let identity = session.identity {
                Button {
                    pendingAction = .keep(identity)
                } label: {
                    Label("Keep with this Google account", systemImage: "person.crop.circle.badge.checkmark")
                }
                .accessibilityHint("Assigns all older imported items and outfit history to \(identity.email) after confirmation.")
                .accessibilityIdentifier("settings.legacyData.keep")
            } else {
                Label("Connect the matching Google account to keep this data", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                pendingAction = .delete
            } label: {
                Label("Delete older imported data", systemImage: "trash")
            }
            .accessibilityHint("Deletes unassigned Gmail imports and outfit history after confirmation. Manual and photo items stay.")
            .accessibilityIdentifier("settings.legacyData.delete")
        } header: {
            Text("Older Imported Data")
        } footer: {
            Text("This data is hidden until you choose. Wardrobe will never guess which Google account owns it.")
        }
    }

    private func failureSection(_ error: LegacyAccountDataError) -> some View {
        Section("Older Imported Data") {
            Label(error.errorDescription ?? "Couldn’t Check Data", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(error.recoverySuggestion ?? "Your older data remains hidden.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Try Again") { controller?.load() }
                .accessibilityIdentifier("settings.legacyData.retry")
        }
    }

    private var confirmationTitle: String {
        switch pendingAction {
        case .keep:
            "Keep older data with this account?"
        case .delete:
            "Delete older imported data?"
        case nil:
            "Confirm data choice"
        }
    }

    private func summaryText(_ summary: LegacyAccountDataSummary) -> String {
        let itemText = "\(summary.importedItems) imported item\(summary.importedItems == 1 ? "" : "s")"
        let outfitText = "\(summary.outfits) outfit\(summary.outfits == 1 ? "" : "s")"
        let wearText = "\(summary.wearLogs) wear record\(summary.wearLogs == 1 ? "" : "s")"
        return "A previous app version saved \(itemText), \(outfitText), and \(wearText) without an account owner."
    }
}
