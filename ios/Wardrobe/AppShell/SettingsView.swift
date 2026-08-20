import SwiftData
import SwiftUI

struct SettingsView: View {
    let devicePrivacy: DevicePrivacySettings
    let onReplayOnboarding: () -> Void
    let onEnterDemo: () -> Void
    let onVerifiedLocalDataDeletion: @MainActor @Sendable () -> Void
    private let serverIdentityDeletion: any ServerIdentityDeleting

    init(
        devicePrivacy: DevicePrivacySettings,
        onReplayOnboarding: @escaping () -> Void,
        onEnterDemo: @escaping () -> Void,
        onVerifiedLocalDataDeletion: @escaping @MainActor @Sendable () -> Void,
        serverIdentityDeletion: any ServerIdentityDeleting = AppAttestAuthorization.shared
    ) {
        self.devicePrivacy = devicePrivacy
        self.onReplayOnboarding = onReplayOnboarding
        self.onEnterDemo = onEnterDemo
        self.onVerifiedLocalDataDeletion = onVerifiedLocalDataDeletion
        self.serverIdentityDeletion = serverIdentityDeletion
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ConnectedFeaturesSettingsView(devicePrivacy: devicePrivacy)
                } label: {
                    SettingsHubRow(
                        title: "Connected Features",
                        subtitle: "AI styling and reminders",
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
                Text(title).font(.body.weight(.semibold))
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
    let devicePrivacy: DevicePrivacySettings

    var body: some View {
        Form {
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
                .accessibilityHint("Shows the introduction again without changing privacy choices.")
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
                LocalDataDeletionView(onVerifiedDeletion: onVerifiedLocalDataDeletion)
            } header: {
                Text("Data on This Device")
            } footer: {
                Text("This removes your local wardrobe, history, cache, reminder, and privacy choices.")
            }

            Section {
                ServerIdentityDeletionView(deletion: serverIdentityDeletion)
            } header: {
                Text("Data on Wardrobe’s Server")
            } footer: {
                Text("This removes only the live anonymous App Attest security record for this installation. It does not delete this iPhone’s wardrobe. Remote AI creates a new anonymous identity the next time you use it. Hosting records follow separate retention in the Privacy Policy.")
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

    var displayText: String { build.isEmpty ? version : "\(version) (\(build))" }
    var accessibilityText: String { build.isEmpty ? version : "\(version), build \(build)" }

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
            Text(text).fixedSize(horizontal: false, vertical: true)
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
                text: "Your catalog is stored by the app on this device. Browsing and adding items require no account."
            )
            privacySection(
                "AI styling",
                symbol: "sparkles",
                text: PrivacyDisclosure.wardrobeStyling.overview
            )
            privacySection(
                "You stay in control",
                symbol: "hand.raised",
                text: "AI styling requires a separate choice and sends data only when you request a look."
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
            Text(text).fixedSize(horizontal: false, vertical: true)
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
            Link(destination: url) { Label(title, systemImage: systemImage) }
                .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            LabeledContent {
                Text("Unavailable").foregroundStyle(.tertiary)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
