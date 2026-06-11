import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var session = GmailSession()
    @State private var pipeline: ReceiptPipeline?
    @State private var pipelineConfigError: String?
    @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext

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
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Signed in (read-only)").font(.headline)
                Text(email).foregroundStyle(.secondary)
                NavigationLink {
                    CatalogView()
                } label: {
                    HStack {
                        Label(
                            "\(items.count) item\(items.count == 1 ? "" : "s") in catalog",
                            systemImage: "square.grid.2x2"
                        )
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, 6)
                syncSection
                Divider().padding(.vertical, 6)

                Button("Sign out") { session.signOut() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            .padding()
        }
    }

    // MARK: - Sync section

    private var syncSection: some View {
        VStack(spacing: 12) {
            Text("Sync receipts").font(.subheadline.weight(.semibold))
            Text("Reads your Gmail (read-only), filters for receipts on-device, sends only the minimal text to the backend.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await runSync() }
            } label: {
                HStack(spacing: 8) {
                    if isSyncing { ProgressView() }
                    Text(syncButtonLabel)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)

            if let error = pipelineConfigError {
                Text("❌ \(error)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(.rect(cornerRadius: 8))
            } else if let pipeline {
                statusView(for: pipeline.state)
            }
        }
    }

    @ViewBuilder
    private func statusView(for state: ReceiptPipeline.State) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case let .running(processed, total):
            VStack(spacing: 4) {
                ProgressView(value: total > 0 ? Double(processed) / Double(total) : 0)
                Text(total > 0
                     ? "Processed \(processed) of \(total)…"
                     : "Fetching receipts…")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        case let .complete(added, candidates, errors):
            VStack(alignment: .leading, spacing: 2) {
                Text("✅ Sync complete").font(.footnote.weight(.semibold))
                Text("• \(candidates) likely receipt\(candidates == 1 ? "" : "s") sent to backend")
                Text("• \(added) item\(added == 1 ? "" : "s") added to catalog")
                if errors > 0 {
                    Text("• \(errors) error\(errors == 1 ? "" : "s") (network / parsing) — see logs")
                        .foregroundStyle(.orange)
                }
            }
            .font(.footnote.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(uiColor: .systemGray6))
            .clipShape(.rect(cornerRadius: 8))
        case let .failed(message):
            Text("❌ \(message)")
                .font(.footnote.monospaced())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(uiColor: .systemGray6))
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var isSyncing: Bool {
        if case .running = pipeline?.state { return true }
        return false
    }

    private var syncButtonLabel: String {
        switch pipeline?.state {
        case .running:    return "Syncing…"
        case .complete:   return "Sync again"
        case .failed:     return "Retry sync"
        default:          return "Sync receipts now"
        }
    }

    /// Lazily build the pipeline on first sync — it needs a signed-in Gmail
    /// session and a configured backend, both of which are known by this point.
    @MainActor
    private func runSync() async {
        if pipeline == nil {
            do {
                guard let gmailClient = session.client else {
                    pipelineConfigError = "Not signed in to Gmail."
                    return
                }
                let (baseURL, deviceToken) = try BackendConfig.load()
                pipeline = ReceiptPipeline(
                    gmailClient: gmailClient,
                    extractClient: ExtractClient(
                        baseURL: baseURL,
                        deviceToken: deviceToken
                    ),
                    modelContext: modelContext
                )
                pipelineConfigError = nil
            } catch {
                pipelineConfigError = "\(error)"
                return
            }
        }
        await pipeline?.sync()
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
