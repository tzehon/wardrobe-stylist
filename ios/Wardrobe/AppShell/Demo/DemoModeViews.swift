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
                    OutfitHistoryView(accountScope: .deviceLocal)
                }
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
                        .accessibilityIdentifier(AppTab.history.accessibilityIdentifier)
                }
                .tag(AppTab.history)

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    bannerMessage
                    exitButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 10) {
                    bannerMessage
                    Spacer(minLength: 8)
                    exitButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .foregroundStyle(Color.white)
        .background(Color.indigo)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demo.banner")
    }

    private var bannerMessage: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(dynamicTypeSize.isAccessibilitySize ? "Demo Mode" : "Demo Mode · Fictional Data")
                    .font(.subheadline.weight(.semibold))
                Text(dynamicTypeSize.isAccessibilitySize ? "Fictional · Offline" : "Offline · Changes are discarded")
                    .font(.caption)
            }
        } icon: {
            Image(systemName: "sparkles.rectangle.stack.fill")
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Demo mode. Fictional data. Offline. Changes are discarded.")
    }

    private var exitButton: some View {
        Button("Exit", action: requestExit)
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint("Asks for confirmation before discarding this fictional demo session.")
            .accessibilityIdentifier("demo.banner.exit")
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
                .accessibilityHint("Asks for confirmation before discarding this fictional demo session.")
                .accessibilityIdentifier("demo.settings.exit")
            }

            Section("Connected Features") {
                LabeledContent("AI network styling", value: "Unavailable in demo")
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(lookItems) { item in
                                accessibleLookItem(item)
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(lookItems) { item in
                                    standardLookItem(item)
                                }
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Items in this fictional look")

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

    private func standardLookItem(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ItemThumbnail(item: item)
                .frame(width: 132, height: 132)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityHidden(true)
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 132, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(itemDescription(item))
    }

    private func accessibleLookItem(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ItemThumbnail(item: item)
                .frame(width: 88, height: 88)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.category.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let brand = item.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(itemDescription(item))
    }

    private func itemDescription(_ item: Item) -> String {
        [item.name, item.brand, item.category.capitalized]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }
}
