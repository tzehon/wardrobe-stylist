import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var session = GmailSession()
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            content.navigationTitle("Wardrobe")
        }
        .task { await session.restorePreviousSignIn() }
    }

    @ViewBuilder private var content: some View {
        switch session.state {
        case .signedOut, .failed:
            signedOutView
        case .signingIn:
            ProgressView("Signing in…")
        case .signedIn(let email):
            signedInView(email: email)
        }
    }

    private var signedOutView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label("Connect your Gmail", systemImage: "envelope.badge")
            } description: {
                Text("Wardrobe reads your Gmail (read-only) to find purchase receipts.")
            }
            Button {
                Task { @MainActor in
                    if let root = topViewController() {
                        await session.signIn(presenting: root)
                    }
                }
            } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            if case .failed(let message) = session.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }

    private func signedInView(email: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Signed in (read-only)").font(.headline)
            Text(email).foregroundStyle(.secondary)
            Text("Catalog is empty — receipt extraction lands in Phase 2.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Button("Sign out") { session.signOut() }
                .buttonStyle(.bordered)
                .padding(.top, 12)
        }
        .padding()
    }
}

/// Best-effort lookup of the active view controller to present sign-in from. SwiftUI
/// doesn't expose this directly, so we climb the connected-scenes/windows tree.
@MainActor
private func topViewController() -> UIViewController? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
}
