import SwiftUI

/// Recoverable launch state shown when SwiftData cannot open the wardrobe.
/// There is deliberately no destructive reset action here.
struct PersistentStoreErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Wardrobe unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(PersistentStoreFailure.userMessage)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
