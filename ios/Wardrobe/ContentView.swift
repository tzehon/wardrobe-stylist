import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var session = GmailSession()
    @State private var smokeTestResult: String?
    @State private var smokeTestLoading = false
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
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Signed in (read-only)").font(.headline)
            Text(email).foregroundStyle(.secondary)
            Text("Catalog is empty — receipt extraction lands in Phase 2.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Divider().padding(.vertical, 4)

            Text("Backend smoke test").font(.subheadline.weight(.semibold))
            Button {
                Task { await runBackendSmokeTest() }
            } label: {
                HStack(spacing: 8) {
                    if smokeTestLoading { ProgressView() }
                    Text(smokeTestLoading ? "Calling /extract…" : "Test backend extraction")
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(smokeTestLoading)

            if let result = smokeTestResult {
                ScrollView {
                    Text(result)
                        .font(.footnote.monospaced())
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 220)
                .background(Color(uiColor: .systemGray6))
                .clipShape(.rect(cornerRadius: 8))
            }

            Button("Sign out") { session.signOut() }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding()
    }

    /// Hand-rolled Everlane-style receipt snippet so we can verify the full
    /// iPhone → LAN → backend → Anthropic → response loop with one tap.
    private func runBackendSmokeTest() async {
        smokeTestLoading = true
        defer { smokeTestLoading = false }
        do {
            let (baseURL, deviceToken) = try BackendConfig.load()
            let client = ExtractClient(baseURL: baseURL, deviceToken: deviceToken)
            let response = try await client.extract(ExtractRequest(
                sourceMsgId: "smoke-test-\(UUID().uuidString.prefix(6))",
                sender: "orders@everlane.com",
                subject: "Order #ABC1234 confirmed",
                snippet: """
                Thanks for your order from Everlane!

                1x Classic Oxford Shirt — White — $78.00

                Order Total: $78.00 USD
                """
            ))
            smokeTestResult = Self.format(response)
        } catch {
            smokeTestResult = "❌ \(error.localizedDescription)\n\n\(String(describing: error))"
        }
    }

    private static func format(_ r: ExtractResponse) -> String {
        var lines: [String] = []
        lines.append("✅ is_fashion: \(r.isFashion)")
        lines.append("items: \(r.items.count)")
        for (index, item) in r.items.enumerated() {
            lines.append("")
            lines.append("\(index + 1). \(item.name)")
            lines.append("   \(item.category.rawValue) · \(item.confidence.rawValue)")
            if let brand = item.brand { lines.append("   brand: \(brand)") }
            if let price = item.price {
                lines.append("   price: \(price) \(item.currency ?? "")")
            }
        }
        lines.append("")
        lines.append(
            "usage: \(r.usage["input_tokens"] ?? 0) in / \(r.usage["output_tokens"] ?? 0) out"
        )
        if let cache = r.usage["cache_read_input_tokens"], cache > 0 {
            lines.append("cache: \(cache) read")
        }
        return lines.joined(separator: "\n")
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
