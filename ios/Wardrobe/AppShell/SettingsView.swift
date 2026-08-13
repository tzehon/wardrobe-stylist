import SwiftData
import SwiftUI

struct SettingsView: View {
    let session: GmailSession
    let onReplayOnboarding: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.name) private var items: [Item]

    @State private var showingSampleRemoval = false
    @State private var sampleError: SampleWardrobeError?

    private var sampleCount: Int {
        items.lazy.filter { SampleWardrobeSeeder.sampleIDs.contains($0.id) }.count
    }

    var body: some View {
        Form {
            Section("Wardrobe") {
                Button {
                    onReplayOnboarding()
                } label: {
                    Label("Replay Introduction", systemImage: "sparkles.rectangle.stack")
                }
                .accessibilityIdentifier("settings.onboarding.replay")

                if sampleCount > 0 {
                    Button(role: .destructive) {
                        showingSampleRemoval = true
                    } label: {
                        Label(
                            "Remove Sample Items",
                            systemImage: "trash"
                        )
                    }
                    .accessibilityHint("Removes only the sample wardrobe. Your own items stay in place.")
                    .accessibilityIdentifier("settings.samples.remove")
                }
            }

            Section {
                GmailConnectorView(session: session)
            } header: {
                Text("Gmail Import")
            } footer: {
                Text("Optional. Your wardrobe and manual item capture work without a Google account.")
            }

            Section("AI & Automation") {
                LabeledContent("Controls", value: "Coming soon")
                    .foregroundStyle(.secondary)
                Text("Data-use choices, background import, and reminder controls will live here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Help & Privacy") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("settings.help")

                NavigationLink {
                    PrivacyOverviewView()
                } label: {
                    Label("Privacy & Data", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("settings.privacy")
            }

            Section("About") {
                LabeledContent("Version", value: AppVersionInfo.current.displayText)
                    .accessibilityIdentifier("settings.appVersion")
            }
        }
        .navigationTitle("Settings")
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

struct AppVersionInfo: Equatable, Sendable {
    let version: String
    let build: String

    var displayText: String {
        build.isEmpty ? version : "\(version) (\(build))"
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
                text: "If you connect Google, Wardrobe requests read-only Gmail access. Receipt candidates are filtered on-device before minimal receipt details are sent for extraction."
            )
            privacySection(
                "AI styling",
                symbol: "sparkles",
                text: "If you allow styling, a compact text catalog is sent for recommendations. Wardrobe photos are not included in the styling request."
            )
            privacySection(
                "You stay in control",
                symbol: "hand.raised",
                text: "Connected features require a separate choice. Signing out of Google does not delete your local wardrobe."
            )
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
