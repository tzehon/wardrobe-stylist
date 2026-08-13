import SwiftData
import SwiftUI

@MainActor
struct DemoModeRootView: View {
    let session: DemoSession
    let onReset: () -> Void
    let onExit: () -> Void

    @State private var selectedTab = AppTab.today
    @State private var confirmingExit = false

    var body: some View {
        VStack(spacing: 0) {
            DemoModeBanner {
                confirmingExit = true
            }

            TabView(selection: $selectedTab) {
                NavigationStack {
                    DemoTodayView()
                }
                .tabItem {
                    Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                        .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
                }
                .tag(AppTab.today)

                NavigationStack {
                    CatalogView(accountScope: .deviceLocal, allowsAddingItems: false)
                }
                .tabItem {
                    Label(AppTab.wardrobe.title, systemImage: AppTab.wardrobe.systemImage)
                        .accessibilityIdentifier(AppTab.wardrobe.accessibilityIdentifier)
                }
                .tag(AppTab.wardrobe)

                NavigationStack {
                    DemoSettingsView(
                        resetDemo: onReset,
                        requestExit: { confirmingExit = true }
                    )
                }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                        .accessibilityIdentifier(AppTab.settings.accessibilityIdentifier)
                }
                .tag(AppTab.settings)
            }
        }
        .modelContainer(session.container)
        .environment(\.isDemoMode, true)
        .confirmationDialog(
            "Exit Demo Mode?",
            isPresented: $confirmingExit,
            titleVisibility: .visible
        ) {
            Button("Exit and Discard Demo Changes", role: .destructive, action: onExit)
            Button("Keep Exploring", role: .cancel) {}
        } message: {
            Text("All changes to this fictional demo wardrobe will be discarded. Your real wardrobe remains untouched.")
        }
    }
}

private struct DemoModeBanner: View {
    let requestExit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Demo Mode · Fictional Data")
                    .font(.subheadline.weight(.semibold))
                Text("Offline · Changes are discarded")
                    .font(.caption2)
            }
            Spacer(minLength: 8)
            Button("Exit", action: requestExit)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("demo.banner.exit")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .foregroundStyle(Color.white)
        .background(Color.indigo)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demo.banner")
    }
}

private struct DemoSettingsView: View {
    let resetDemo: () -> Void
    let requestExit: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("Demo Mode") {
                Label("Fictional sample wardrobe", systemImage: "sparkles.rectangle.stack")
                Label("Runs entirely offline", systemImage: "network.slash")
                Label("Edits are discarded on exit", systemImage: "arrow.uturn.backward.circle")

                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("Reset Fictional Demo Data", systemImage: "trash")
                }
                .accessibilityHint("Deletes all demo edits and reloads the bundled fictional wardrobe. Your real wardrobe is not affected.")
                .accessibilityIdentifier("demo.settings.reset")

                Button(role: .destructive, action: requestExit) {
                    Label("Exit Demo Mode", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityIdentifier("demo.settings.exit")
            }

            Section("Connected Features") {
                LabeledContent("Google sign-in", value: "Unavailable in demo")
                LabeledContent("Gmail import", value: "Unavailable in demo")
                LabeledContent("AI network styling", value: "Unavailable in demo")
                LabeledContent("Background tasks", value: "Unavailable in demo")
                LabeledContent("Notifications", value: "Unavailable in demo")
            }
        }
        .navigationTitle("Demo Settings")
        .confirmationDialog(
            "Reset fictional demo data?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete Demo Changes and Reset", role: .destructive, action: resetDemo)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes only the disposable fictional demo wardrobe. Your real wardrobe remains untouched.")
        }
    }
}

struct DemoTodayView: View {
    @Query(sort: \Item.name) private var items: [Item]

    private var lookItems: [Item] {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return DemoWardrobe.todayLook.itemIDs.compactMap { byID[$0] }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Fictional offline recommendation", systemImage: "network.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)

                Text(DemoWardrobe.todayLook.occasion)
                    .font(.title2.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(lookItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                ItemThumbnail(item: item)
                                    .frame(width: 132, height: 132)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(.rect(cornerRadius: 14))
                                Text(item.name)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .frame(width: 132, alignment: .leading)
                            }
                        }
                    }
                }

                Text(DemoWardrobe.todayLook.colorStory)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(DemoWardrobe.todayLook.rationale)
                    .fixedSize(horizontal: false, vertical: true)

                Label("This look is bundled with the demo. No wardrobe data was sent anywhere.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("demo.today")
    }
}
