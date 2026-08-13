import SwiftData
import SwiftUI
import UIKit

private enum ConnectedStatusTone {
    case information
    case warning
    case error

    var color: Color {
        switch self {
        case .information: .secondary
        case .warning: .orange
        case .error: .red
        }
    }

    var systemImage: String {
        switch self {
        case .information: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var accessibilityPrefix: String {
        switch self {
        case .information: "Information"
        case .warning: "Attention"
        case .error: "Error"
        }
    }
}

/// Optional Google connection. The account can authorize Gmail before it
/// authorizes receipt analysis; those are deliberately separate choices.
struct GmailConnectorView: View {
    let session: GmailSession
    let devicePrivacy: DevicePrivacySettings
    let syncActivity: ReceiptSyncActivityController
    private let makePrivacySettings: @MainActor (GoogleSignInIdentity) -> GmailPrivacySettings

    init(
        session: GmailSession,
        devicePrivacy: DevicePrivacySettings,
        syncActivity: ReceiptSyncActivityController,
        makePrivacySettings: (@MainActor (GoogleSignInIdentity) -> GmailPrivacySettings)? = nil
    ) {
        self.session = session
        self.devicePrivacy = devicePrivacy
        self.syncActivity = syncActivity
        self.makePrivacySettings = makePrivacySettings ?? { [devicePrivacy] identity in
            GmailPrivacySettings(
                subjectID: identity.privacySubjectID,
                devicePrivacy: devicePrivacy
            )
        }
    }

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
                    devicePrivacy: devicePrivacy,
                    syncActivity: syncActivity,
                    privacy: makePrivacySettings(identity)
                )
                .id(identity.stableUserID)
            case .reconnectRequired(let message):
                disconnectedContent
                statusMessage(message, tone: .warning)
            case .cancelled:
                disconnectedContent
                statusMessage("Google sign-in was cancelled. Nothing was connected.", tone: .information)
            case .failed(let message):
                disconnectedContent
                statusMessage(message, tone: .error)
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
            .controlSize(.large)
            .accessibilityHint("Connects an optional read-only Gmail account. Receipt analysis remains off until you allow it separately.")
            .accessibilityIdentifier("settings.gmail.connect")

            if let localError {
                statusMessage(localError, tone: .error)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier("settings.gmail.progress")
    }

    private func statusMessage(_ message: String, tone: ConnectedStatusTone) -> some View {
        Label {
            Text(message)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: tone.systemImage)
                .foregroundStyle(tone.color)
        }
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(tone.accessibilityPrefix): \(message)")
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
    let syncActivity: ReceiptSyncActivityController

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
        devicePrivacy: DevicePrivacySettings,
        syncActivity: ReceiptSyncActivityController,
        privacy: GmailPrivacySettings? = nil
    ) {
        self.session = session
        self.identity = identity
        self.syncActivity = syncActivity
        _privacy = State(initialValue: privacy ?? GmailPrivacySettings(
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
                statusMessage(errorMessage, tone: .error)
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
            Label {
                Text("Connected (read-only)")
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
            .font(.headline)
            Text(identity.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("\(items.count) item\(items.count == 1 ? "" : "s") in your local wardrobe")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connected read-only Gmail account, \(identity.email), \(items.count) local wardrobe item\(items.count == 1 ? "" : "s")")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading this account’s privacy choice")
        case .unavailable(let failure):
            statusMessage(failure.userMessage, tone: .error)
            Button("Try loading again") {
                Task { await privacy.controls.load() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Attempts to load this account’s privacy choice again. Protected features stay off until it succeeds.")
        case .loaded:
            if receiptAnalysisAllowed {
                Label {
                    Text("Receipt analysis allowed for this Google account")
                } icon: {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }
                    .font(.subheadline.weight(.semibold))
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
                        let completed = await syncActivity.withQuiesced {
                            guard await privacy.withdrawReceiptAnalysis() else { return false }
                            pipeline = nil
                            pipelineConfigError = nil
                            return true
                        }
                        if completed == nil {
                            pipelineConfigError = "Another privacy or data operation is already in progress. Please try again."
                        }
                    }
                }
                .disabled(privacy.isUpdating || accountAction != .idle)
                .controlSize(.large)
                .accessibilityHint("Turns off receipt analysis and background import after any active import stops. Your local wardrobe stays in place.")
                .accessibilityIdentifier("settings.gmail.withdrawReceiptAnalysis")
            } else {
                Button {
                    Task { _ = await privacy.grantReceiptAnalysis() }
                } label: {
                    Label("Allow receipt analysis", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
                .accessibilityHint("Allows limited receipt details to be analyzed only when you start an import. This does not enable background import.")
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
            .controlSize(.large)
            .disabled(isBusy)
            .accessibilityIdentifier("settings.gmail.sync")

            if isSyncing || syncActivity.isRunning {
                Button("Stop current import", role: .cancel) {
                    Task { _ = await syncActivity.cancelAndWait() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Cancels the current import after its active read-only request stops. Items already saved remain in your wardrobe.")
                .accessibilityIdentifier("settings.gmail.sync.cancel")
            }

            if let pipelineConfigError {
                statusMessage(pipelineConfigError, tone: .error)
            } else if let pipeline {
                pipelineStatus(pipeline.state)
            } else if syncActivity.isRunning {
                statusMessage("Another receipt import is already running. You can stop it by signing out, disconnecting Google, or deleting local data.", tone: .information)
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
            .controlSize(.large)
            .disabled(privacy.isUpdating || accountAction != .idle)
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
            .disabled(privacy.isUpdating || accountAction != .idle)
            .controlSize(.large)
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
                .fixedSize(horizontal: false, vertical: true)
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
            .accessibilityLabel(total > 0
                ? "Receipt import progress: processed \(processed) of \(total)"
                : "Receipt import progress: fetching likely receipts")
        case let .complete(added, candidates, errors):
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text("Import complete")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                    .font(.footnote.weight(.semibold))
                Text("\(added) item\(added == 1 ? "" : "s") added from \(candidates) likely receipt\(candidates == 1 ? "" : "s").")
                if errors > 0 {
                    Label {
                        Text("\(errors) message\(errors == 1 ? "" : "s") could not be processed.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
        case .failed(let message):
            statusMessage(
                ReceiptImportPresentation.failureMessage(for: message),
                tone: .error
            )
        }
    }

    private func statusMessage(_ message: String, tone: ConnectedStatusTone) -> some View {
        Label {
            Text(message)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: tone.systemImage)
                .foregroundStyle(tone.color)
        }
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(tone.accessibilityPrefix): \(message)")
            .accessibilityIdentifier("settings.gmail.status")
    }

    private var isSyncing: Bool {
        if case .running = pipeline?.state { return true }
        return false
    }

    private var isBusy: Bool {
        syncActivity.isRunning || syncActivity.isQuiesced
            || privacy.isUpdating || accountAction != .idle
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
                pipelineConfigError = ReceiptImportPresentation.configurationUnavailable
                return
            }
        }
        guard let pipeline else { return }
        let started = await syncActivity.run {
            await pipeline.sync(mode: .manual)
        }
        if !started {
            pipelineConfigError = "Another receipt import is already running. Please wait or stop it first."
        }
    }

    @MainActor
    private func signOut() async {
        accountAction = .signingOut
        defer { accountAction = .idle }
        let completed = await syncActivity.withQuiesced {
            guard await privacy.prepareForAccountExit() else { return false }
            pipeline = nil
            pipelineConfigError = nil
            session.signOut()
            return true
        }
        if completed == nil {
            pipelineConfigError = "Another privacy or data operation is already in progress. Please try again."
        }
    }

    @MainActor
    private func disconnect() async {
        accountAction = .disconnecting
        defer { accountAction = .idle }
        let completed = await syncActivity.withQuiesced {
            guard await privacy.prepareForAccountExit() else { return false }
            pipeline = nil
            pipelineConfigError = nil
            await session.disconnect()
            guard case .signedOut = session.status else { return false }
            await privacy.clearRevokedAccountPreferences()
            return true
        }
        if completed == nil {
            pipelineConfigError = "Another privacy or data operation is already in progress. Please try again."
        }
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
