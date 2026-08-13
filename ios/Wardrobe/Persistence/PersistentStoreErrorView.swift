import SwiftUI

/// Recoverable launch state shown when SwiftData cannot open the wardrobe.
/// There is deliberately no destructive reset action here.
struct PersistentStoreErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Wardrobe unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(PersistentStoreFailure.userMessage)
                Text("Wardrobe will not reset or delete your data automatically.")
            }
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Attempts to open the existing wardrobe again without deleting it.")
                .accessibilityIdentifier("persistence.retry")
        }
    }
}
