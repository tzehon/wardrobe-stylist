import SwiftData
import SwiftUI

struct SettingsView: View {
    let session: GmailSession
    let devicePrivacy: DevicePrivacySettings
    let syncActivity: ReceiptSyncActivityController
    let onReplayOnboarding: () -> Void
    let onEnterDemo: () -> Void
    let onVerifiedLocalDataDeletion: @MainActor @Sendable () -> Void
    private let makeGmailPrivacySettings: (@MainActor (GoogleSignInIdentity) -> GmailPrivacySettings)?
    private let serverIdentityDeletion: any ServerIdentityDeleting

    init(
        session: GmailSession,
        devicePrivacy: DevicePrivacySettings,
        syncActivity: ReceiptSyncActivityController,
        onReplayOnboarding: @escaping () -> Void,
        onEnterDemo: @escaping () -> Void,
        onVerifiedLocalDataDeletion: @escaping @MainActor @Sendable () -> Void,
        makeGmailPrivacySettings: (@MainActor (GoogleSignInIdentity) -> GmailPrivacySettings)? = nil,
        serverIdentityDeletion: any ServerIdentityDeleting = AppAttestAuthorization.shared
    ) {
        self.session = session
        self.devicePrivacy = devicePrivacy
        self.syncActivity = syncActivity
        self.onReplayOnboarding = onReplayOnboarding
        self.onEnterDemo = onEnterDemo
        self.onVerifiedLocalDataDeletion = onVerifiedLocalDataDeletion
        self.makeGmailPrivacySettings = makeGmailPrivacySettings
        self.serverIdentityDeletion = serverIdentityDeletion
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ConnectedFeaturesSettingsView(
                        session: session,
                        devicePrivacy: devicePrivacy,
                        syncActivity: syncActivity,
                        makeGmailPrivacySettings: makeGmailPrivacySettings
                    )
                } label: {
                    SettingsHubRow(
                        title: "Connected Features",
                        subtitle: "Gmail import, AI styling, and reminders",
                        systemImage: "wand.and.sparkles",
                        color: .purple
                    )
                }
                .accessibilityIdentifier("settings.hub.connected")

                NavigationLink {
                    WardrobeToolsSettingsView(
                        onReplayOnboarding: onReplayOnboarding,
                        onEnterDemo: onEnterDemo
                    )
                } label: {
                    SettingsHubRow(
                        title: "Wardrobe & Demo",
                        subtitle: "Introduction, offline demo, and samples",
                        systemImage: "hanger",
                        color: .pink
                    )
                }
                .accessibilityIdentifier("settings.hub.wardrobe")

                NavigationLink {
                    PrivacyAndDataSettingsView(
                        session: session,
                        syncActivity: syncActivity,
                        serverIdentityDeletion: serverIdentityDeletion,
                        onVerifiedLocalDataDeletion: onVerifiedLocalDataDeletion
                    )
                } label: {
                    SettingsHubRow(
                        title: "Privacy & Data",
                        subtitle: "Data use, privacy policy, and deletion",
                        systemImage: "hand.raised.fill",
                        color: .blue
                    )
                }
                .accessibilityIdentifier("settings.hub.privacy")

                NavigationLink {
                    HelpAndSupportSettingsView()
                } label: {
                    SettingsHubRow(
                        title: "Help & Support",
                        subtitle: "How-to guidance and contact options",
                        systemImage: "questionmark.circle.fill",
                        color: .orange
                    )
                }
                .accessibilityIdentifier("settings.hub.help")
            }

            Section {
                LabeledContent("Version", value: AppVersionInfo.current.displayText)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("App version \(AppVersionInfo.current.accessibilityText)")
                    .accessibilityIdentifier("settings.appVersion")
            }
        }
        .navigationTitle("Settings")
    }
}

private struct SettingsHubRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ConnectedFeaturesSettingsView: View {
    let session: GmailSession
    let devicePrivacy: DevicePrivacySettings
    let syncActivity: ReceiptSyncActivityController
    let makeGmailPrivacySettings: (@MainActor (GoogleSignInIdentity) -> GmailPrivacySettings)?

    var body: some View {
        Form {
            Section {
                GmailConnectorView(
                    session: session,
                    devicePrivacy: devicePrivacy,
                    syncActivity: syncActivity,
                    makePrivacySettings: makeGmailPrivacySettings
                )
            } header: {
                Text("Gmail Import")
            } footer: {
                Text("Optional. Your wardrobe and camera work without Google.")
            }

            LegacyAccountDataResolutionView(session: session)

            Section("AI Styling & Reminder") {
                StylingPrivacySettingsView(settings: devicePrivacy)
            }
        }
        .navigationTitle("Connected Features")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WardrobeToolsSettingsView: View {
    let onReplayOnboarding: () -> Void
    let onEnterDemo: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.name) private var items: [Item]

    @State private var showingSampleRemoval = false
    @State private var sampleError: SampleWardrobeError?

    private var sampleCount: Int {
        items.lazy.filter { SampleWardrobeSeeder.sampleIDs.contains($0.id) }.count
    }

    var body: some View {
        Form {
            Section {
                Button {
                    onReplayOnboarding()
                } label: {
                    Label("Replay Introduction", systemImage: "rectangle.stack.badge.play")
                }
                .accessibilityHint("Shows the introduction again without changing privacy or account choices.")
                .accessibilityIdentifier("settings.onboarding.replay")

                Button(action: onEnterDemo) {
                    Label("Open Offline Demo", systemImage: "sparkles.rectangle.stack")
                }
                .accessibilityHint("Opens a fictional, disposable wardrobe. Connected features stay off and your real wardrobe remains untouched.")
                .accessibilityIdentifier("settings.demo.enter")

                if sampleCount > 0 {
                    Button(role: .destructive) {
                        showingSampleRemoval = true
                    } label: {
                        Label("Remove Sample Items", systemImage: "trash")
                    }
                    .accessibilityHint("Removes only the sample wardrobe. Your own items stay in place.")
                    .accessibilityIdentifier("settings.samples.remove")
                }
            }
        }
        .navigationTitle("Wardrobe & Demo")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove sample items?",
            isPresented: $showingSampleRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Samples", role: .destructive, action: removeSamples)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the bundled sample pieces will be removed. Your own wardrobe items will stay in place.")
        }
        .alert(
            sampleError?.errorDescription ?? "Couldn’t Update Samples",
            isPresented: Binding(
                get: { sampleError != nil },
                set: { if !$0 { sampleError = nil } }
            ),
            presenting: sampleError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.recoverySuggestion ?? "Please try again.")
        }
    }

    private func removeSamples() {
        do {
            try SampleWardrobeSeeder(modelContext: modelContext).remove()
        } catch let error as SampleWardrobeError {
            sampleError = error
        } catch {
            sampleError = SampleWardrobeError(diagnostic: String(describing: error))
        }
    }
}

private struct PrivacyAndDataSettingsView: View {
    let session: GmailSession
    let syncActivity: ReceiptSyncActivityController
    let serverIdentityDeletion: any ServerIdentityDeleting
    let onVerifiedLocalDataDeletion: @MainActor @Sendable () -> Void

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    PrivacyOverviewView(links: .current)
                } label: {
                    Label("How Your Data Is Used", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("settings.privacy")

                ConfiguredExternalLink(
                    title: "Privacy Policy",
                    systemImage: "doc.text",
                    url: AppExternalLinks.current.privacyPolicyURL,
                    accessibilityIdentifier: "settings.privacyPolicy"
                )
            }

            Section {
                LocalDataDeletionView(
                    activeExternalSubject: session.privacySubjectID,
                    syncActivity: syncActivity,
                    onVerifiedDeletion: onVerifiedLocalDataDeletion
                )
            } header: {
                Text("Data on This Device")
            } footer: {
                Text("Deleting local data does not revoke Google access. Use Disconnect Google under Connected Features for that.")
            }

            Section {
                ServerIdentityDeletionView(
                    deletion: serverIdentityDeletion,
                    syncActivity: syncActivity
                )
            } header: {
                Text("Data on Wardrobe’s Server")
            } footer: {
                Text("This removes only anonymous App Attest security metadata for this installation. It does not delete this iPhone’s wardrobe or disconnect Google. Remote AI creates a new anonymous identity the next time you use it.")
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpAndSupportSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("How to Use Wardrobe", systemImage: "book")
                }
                .accessibilityIdentifier("settings.help")

                ConfiguredExternalLink(
                    title: "Support",
                    systemImage: "lifepreserver",
                    url: AppExternalLinks.current.supportURL,
                    accessibilityIdentifier: "settings.support"
                )

                ConfiguredExternalLink(
                    title: "Privacy Policy",
                    systemImage: "doc.text",
                    url: AppExternalLinks.current.privacyPolicyURL,
                    accessibilityIdentifier: "settings.help.privacyPolicy"
                )
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppVersionInfo: Equatable, Sendable {
    let version: String
    let build: String

    var displayText: String {
        build.isEmpty ? version : "\(version) (\(build))"
    }

    var accessibilityText: String {
        build.isEmpty ? version : "\(version), build \(build)"
    }

    static var current: AppVersionInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppVersionInfo(
            version: info["CFBundleShortVersionString"] as? String ?? "—",
            build: info["CFBundleVersion"] as? String ?? ""
        )
    }
}

private struct HelpView: View {
    var body: some View {
        List {
            helpSection(
                "Build your wardrobe",
                symbol: "plus.circle",
                text: "Open Wardrobe and tap Add Item. Choose a photo or camera image, then add the details you know."
            )
            helpSection(
                "Browse and tidy",
                symbol: "square.grid.2x2",
                text: "Search by item name or brand, filter by category, and use the sort menu to change the catalog order."
            )
            helpSection(
                "Import receipts",
                symbol: "envelope",
                text: "Gmail import is optional and read-only. Connect it in Settings, review data use, then start a sync yourself."
            )
            helpSection(
                "Get a look",
                symbol: "sparkles",
                text: "Today can style a look after you add enough pieces and choose to allow AI styling."
            )
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpSection(_ title: String, symbol: String, text: String) -> some View {
        Section {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Label(title, systemImage: symbol)
        }
    }
}

private struct PrivacyOverviewView: View {
    let links: AppExternalLinks

    var body: some View {
        List {
            privacySection(
                "Local wardrobe",
                symbol: "iphone",
                text: "Your catalog is stored by the app on this device. Browsing and adding items do not require Gmail."
            )
            privacySection(
                "Gmail receipts",
                symbol: "envelope.badge.shield.half.filled",
                text: "If you connect Google, Wardrobe requests read-only Gmail access. Likely purchase messages are filtered on-device before limited receipt details are sent to the developer-operated backend and Anthropic Claude for extraction."
            )
            privacySection(
                "AI styling",
                symbol: "sparkles",
                text: "If you allow styling and ask for a look, a compact text catalog, recent item identifiers, and per-item average rating and rating count are sent to the developer-operated backend and Anthropic Claude. Free-text feedback, outfit rationales, rating dates, wardrobe photos, and Gmail messages are not included in styling requests."
            )
            privacySection(
                "You stay in control",
                symbol: "hand.raised",
                text: "Connected features require a separate choice. Signing out of Google does not delete your local wardrobe."
            )
            privacySection(
                "Google Limited Use",
                symbol: "checkmark.shield",
                text: "Wardrobe Stylist’s use and transfer of information received from Google APIs adheres to the Google API Services User Data Policy, including its Limited Use requirements."
            )

            Section("External information") {
                ConfiguredExternalLink(
                    title: "Privacy Policy",
                    systemImage: "doc.text",
                    url: links.privacyPolicyURL,
                    accessibilityIdentifier: "privacyOverview.privacyPolicy"
                )
                ConfiguredExternalLink(
                    title: "Support",
                    systemImage: "lifepreserver",
                    url: links.supportURL,
                    accessibilityIdentifier: "privacyOverview.support"
                )
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(_ title: String, symbol: String, text: String) -> some View {
        Section {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Label(title, systemImage: symbol)
        }
    }
}

private struct ConfiguredExternalLink: View {
    let title: String
    let systemImage: String
    let url: URL?
    let accessibilityIdentifier: String

    var body: some View {
        if let url {
            Link(destination: url) {
                Label(title, systemImage: systemImage)
            }
            .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            LabeledContent {
                Text("Unavailable")
                    .foregroundStyle(.tertiary)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .foregroundStyle(.secondary)
            .accessibilityHint("This link has not been configured for this build.")
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
