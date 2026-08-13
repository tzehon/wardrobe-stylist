import SwiftData
import SwiftUI
import UIKit

/// Optional Google connection. The account can authorize Gmail before it
/// authorizes receipt analysis; those are deliberately separate choices.
struct GmailConnectorView: View {
    let session: GmailSession
    let devicePrivacy: DevicePrivacySettings

    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.status {
            case .restoring:
                progress("Restoring Google connection…")
            case .signedOut:
                disconnectedContent
            case .signingIn:
                progress("Connecting to Google…")
            case .signedIn(let identity):
                ConnectedGmailView(
                    session: session,
                    identity: identity,
                    devicePrivacy: devicePrivacy
                )
                .id(identity.stableUserID)
            case .reconnectRequired(let message):
                disconnectedContent
                statusMessage(message, color: .orange)
            case .cancelled:
                disconnectedContent
                statusMessage("Google sign-in was cancelled. Nothing was connected.", color: .secondary)
            case .failed(let message):
                disconnectedContent
                statusMessage(message, color: .red)
            }
        }
    }

    private var disconnectedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not connected", systemImage: "envelope.badge")
                .font(.headline)
            Text("Connect only if you want to import purchase receipts. Wardrobe requests read-only Gmail access; connecting does not start an import or allow receipt analysis.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { @MainActor in
                    guard let presenter = topViewController() else {
                        localError = "Couldn’t open Google sign-in. Please try again."
                        return
                    }
                    localError = nil
                    await session.signIn(presenting: presenter)
                }
            } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Connects an optional read-only Gmail account. Receipt analysis remains off until you allow it separately.")
            .accessibilityIdentifier("settings.gmail.connect")

            if let localError {
                statusMessage(localError, color: .red)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
        }
        .accessibilityIdentifier("settings.gmail.progress")
    }

    private func statusMessage(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.gmail.status")
    }
}

private struct ConnectedGmailView: View {
    private enum AccountAction: Equatable {
        case idle
        case signingOut
        case disconnecting
    }

    let session: GmailSession
    let identity: GoogleSignInIdentity

    @Environment(\.modelContext) private var modelContext
    @Query private var storedItems: [Item]

    @State private var privacy: GmailPrivacySettings
    @State private var pipeline: ReceiptPipeline?
    @State private var pipelineConfigError: String?
    @State private var accountAction = AccountAction.idle
    @State private var showingSignOutConfirmation = false
    @State private var showingDisconnectConfirmation = false

    init(
        session: GmailSession,
        identity: GoogleSignInIdentity,
        devicePrivacy: DevicePrivacySettings
    ) {
        self.session = session
        self.identity = identity
        _privacy = State(initialValue: GmailPrivacySettings(
            subjectID: identity.privacySubjectID,
            devicePrivacy: devicePrivacy
        ))
    }

    private var receiptAnalysisAllowed: Bool {
        privacy.controls.decision(for: .manualReceiptImport).isAllowed
    }

    private var preferences: AccountPrivacyPreferences? {
        privacy.controls.preferences
    }

    private var items: [Item] {
        WardrobeAccountFilter.visibleItems(
            from: storedItems,
            in: .external(identity.privacySubjectID)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            accountHeader
            PrivacyDisclosureView(disclosure: .receiptAnalysis)
            privacyControls

            if let errorMessage = privacy.errorMessage {
                statusMessage(errorMessage, color: .red)
            }

            Divider()
            accountActions
        }
        .task { await privacy.load() }
        .confirmationDialog(
            "Sign out on this device?",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out") {
                Task { await signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Background import and the daily reminder will be turned off. Your local wardrobe, Google permission, and saved receipt-analysis choice remain.")
        }
        .confirmationDialog(
            "Disconnect Google?",
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect Google", role: .destructive) {
                Task { await disconnect() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wardrobe will revoke its Google access and clear this account’s receipt-analysis choice. Background import and the daily reminder will turn off. Local wardrobe items remain on this device.")
        }
    }

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Connected (read-only)", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(identity.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("\(items.count) item\(items.count == 1 ? "" : "s") in your local wardrobe")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var privacyControls: some View {
        switch privacy.controls.state {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading this account’s privacy choice…")
                    .foregroundStyle(.secondary)
            }
        case .unavailable(let failure):
            statusMessage(failure.userMessage, color: .red)
            Button("Try loading again") {
                Task { await privacy.controls.load() }
            }
            .buttonStyle(.bordered)
        case .loaded:
            if receiptAnalysisAllowed {
                Label("Receipt analysis allowed for this Google account", systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("settings.gmail.receiptAnalysisAllowed")

                Toggle(
                    "Background receipt import",
                    isOn: Binding(
                        get: { preferences?.backgroundReceiptSyncEnabled ?? false },
                        set: { isEnabled in
                            Task { @MainActor in
                                _ = await privacy.setBackgroundImportEnabled(isEnabled)
                            }
                        }
                    )
                )
                .disabled(isBusy)
                .accessibilityHint("Lets iOS run an occasional receipt import when system conditions allow. Timing is not guaranteed.")
                .accessibilityIdentifier("settings.gmail.backgroundImport")

                Text("Off by default. iOS decides whether and when background work runs, so imports are not guaranteed to happen daily.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                syncControls

                Button("Withdraw receipt-analysis permission", role: .destructive) {
                    Task {
                        if await privacy.withdrawReceiptAnalysis() {
                            pipeline = nil
                            pipelineConfigError = nil
                        }
                    }
                }
                .disabled(isBusy)
                .accessibilityIdentifier("settings.gmail.withdrawReceiptAnalysis")
            } else {
                Button {
                    Task { _ = await privacy.grantReceiptAnalysis() }
                } label: {
                    Label("Allow receipt analysis", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                .accessibilityIdentifier("settings.gmail.allowReceiptAnalysis")

                Text("Off by default. Connecting Google alone does not read or send receipt content for analysis.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var syncControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await runSync() }
            } label: {
                HStack(spacing: 8) {
                    if isSyncing { ProgressView() }
                    Text(syncButtonLabel)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
            .accessibilityIdentifier("settings.gmail.sync")

            if let pipelineConfigError {
                statusMessage(pipelineConfigError, color: .red)
            } else if let pipeline {
                pipelineStatus(pipeline.state)
            }
        }
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showingSignOutConfirmation = true
            } label: {
                accountActionLabel(
                    title: "Sign out on this device",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    activeAction: .signingOut
                )
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .accessibilityHint("Ends the local session after turning automations off. Google access and account consent remain.")
            .accessibilityIdentifier("settings.gmail.signOut")

            Button(role: .destructive) {
                showingDisconnectConfirmation = true
            } label: {
                accountActionLabel(
                    title: "Disconnect Google",
                    systemImage: "link.badge.minus",
                    activeAction: .disconnecting
                )
            }
            .disabled(isBusy)
            .accessibilityHint("Revokes Google access and clears this account’s receipt-analysis choice after turning automations off.")
            .accessibilityIdentifier("settings.gmail.disconnect")
        }
    }

    private func accountActionLabel(
        title: String,
        systemImage: String,
        activeAction: AccountAction
    ) -> some View {
        HStack(spacing: 8) {
            if accountAction == activeAction { ProgressView() }
            Label(title, systemImage: systemImage)
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
                Text(total > 0 ? "Processed \(processed) of \(total)…" : "Fetching likely receipts…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        case let .complete(added, candidates, errors):
            VStack(alignment: .leading, spacing: 3) {
                Label("Import complete", systemImage: "checkmark.circle.fill")
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

    private var isBusy: Bool {
        isSyncing || privacy.isUpdating || accountAction != .idle
    }

    private var syncButtonLabel: String {
        switch pipeline?.state {
        case .running: "Importing…"
        case .complete: "Import again"
        case .failed: "Retry import"
        default: "Import receipts now"
        }
    }

    @MainActor
    private func runSync() async {
        guard receiptAnalysisAllowed else {
            pipelineConfigError = "Allow receipt analysis before starting an import."
            return
        }
        if pipeline == nil {
            do {
                guard let gmailClient = session.client,
                      session.privacySubjectID == identity.privacySubjectID else {
                    pipelineConfigError = "Reconnect Gmail before starting a receipt import."
                    return
                }
                let (baseURL, deviceToken) = try BackendConfig.load()
                pipeline = ReceiptPipeline(
                    gmailClient: gmailClient,
                    extractClient: ExtractClient(baseURL: baseURL, deviceToken: deviceToken),
                    modelContext: modelContext,
                    privacySubjectID: identity.privacySubjectID
                )
                pipelineConfigError = nil
            } catch {
                pipelineConfigError = error.localizedDescription
                return
            }
        }
        await pipeline?.sync(mode: .manual)
    }

    @MainActor
    private func signOut() async {
        accountAction = .signingOut
        defer { accountAction = .idle }
        guard await privacy.prepareForAccountExit() else { return }
        pipeline = nil
        pipelineConfigError = nil
        session.signOut()
    }

    @MainActor
    private func disconnect() async {
        accountAction = .disconnecting
        defer { accountAction = .idle }
        guard await privacy.prepareForAccountExit() else { return }
        pipeline = nil
        pipelineConfigError = nil
        await session.disconnect()
        guard case .signedOut = session.status else { return }
        await privacy.clearRevokedAccountPreferences()
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
