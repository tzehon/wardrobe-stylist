import SwiftData
import SwiftUI
import UIKit

/// Optional Gmail account and receipt-import controls. Failures here are kept
/// inside Settings so local Wardrobe and Today navigation always remain usable.
struct GmailConnectorView: View {
    let session: GmailSession

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var pipeline: ReceiptPipeline?
    @State private var pipelineConfigError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.state {
            case .signedOut:
                disconnectedContent
            case .signingIn:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Connecting to Google…")
                }
                .accessibilityIdentifier("settings.gmail.progress")
            case .failed(let message):
                disconnectedContent
                statusMessage(message, color: .red)
            case .signedIn(let email):
                connectedContent(email: email)
            }
        }
    }

    private var disconnectedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not connected", systemImage: "envelope.badge")
                .font(.headline)
            Text("Connect only if you want to import purchase receipts. Wardrobe requests read-only Gmail access.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { @MainActor in
                    guard let presenter = topViewController() else {
                        pipelineConfigError = "Couldn’t open Google sign-in. Please try again."
                        return
                    }
                    pipeline = nil
                    pipelineConfigError = nil
                    await session.signIn(presenting: presenter)
                }
            } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Connects an optional read-only Gmail account for receipt import.")
            .accessibilityIdentifier("settings.gmail.connect")

            if let pipelineConfigError {
                statusMessage(pipelineConfigError, color: .red)
            }
        }
    }

    private func connectedContent(email: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connected (read-only)", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("\(items.count) item\(items.count == 1 ? "" : "s") in your wardrobe")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await runSync() }
            } label: {
                HStack(spacing: 8) {
                    if isSyncing { ProgressView() }
                    Text(syncButtonLabel)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)
            .accessibilityIdentifier("settings.gmail.sync")

            if let pipelineConfigError {
                statusMessage(pipelineConfigError, color: .red)
            } else if let pipeline {
                pipelineStatus(pipeline.state)
            }

            Button("Sign out") {
                pipeline = nil
                pipelineConfigError = nil
                session.signOut()
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Disconnects this app session. Your local wardrobe stays on this device.")
            .accessibilityIdentifier("settings.gmail.signOut")
        }
    }

    @ViewBuilder
    private func pipelineStatus(_ state: ReceiptPipeline.State) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case let .running(processed, total):
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: total > 0 ? Double(processed) / Double(total) : 0)
                Text(total > 0 ? "Processed \(processed) of \(total)…" : "Fetching receipts…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        case let .complete(added, candidates, errors):
            VStack(alignment: .leading, spacing: 3) {
                Label("Sync complete", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
                Text("\(added) item\(added == 1 ? "" : "s") added from \(candidates) likely receipt\(candidates == 1 ? "" : "s").")
                if errors > 0 {
                    Text("\(errors) message\(errors == 1 ? "" : "s") could not be processed.")
                        .foregroundStyle(.orange)
                }
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
        case .failed(let message):
            statusMessage(message, color: .red)
        }
    }

    private func statusMessage(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.gmail.status")
    }

    private var isSyncing: Bool {
        if case .running = pipeline?.state { return true }
        return false
    }

    private var syncButtonLabel: String {
        switch pipeline?.state {
        case .running: "Syncing…"
        case .complete: "Sync again"
        case .failed: "Retry sync"
        default: "Sync receipts now"
        }
    }

    @MainActor
    private func runSync() async {
        if pipeline == nil {
            do {
                guard let gmailClient = session.client,
                      let privacySubjectID = session.privacySubjectID else {
                    pipelineConfigError = "Connect Gmail before starting a receipt sync."
                    return
                }
                let (baseURL, deviceToken) = try BackendConfig.load()
                pipeline = ReceiptPipeline(
                    gmailClient: gmailClient,
                    extractClient: ExtractClient(baseURL: baseURL, deviceToken: deviceToken),
                    modelContext: modelContext,
                    privacySubjectID: privacySubjectID
                )
                pipelineConfigError = nil
            } catch {
                pipelineConfigError = error.localizedDescription
                return
            }
        }
        await pipeline?.sync()
    }
}

/// Best-effort lookup of the active view controller used to present Google
/// sign-in. SwiftUI does not expose a presenter directly.
@MainActor
private func topViewController() -> UIViewController? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
}
