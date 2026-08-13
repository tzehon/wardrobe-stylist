import SwiftUI

struct ContentView: View {
    @State private var session = GmailSession()
    @State private var onboardingState = OnboardingState()
    @SceneStorage("com.tth.Wardrobe.selectedTab")
    private var selectedTabRawValue = AppTab.wardrobe.rawValue

    var body: some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
            }
            .tag(AppTab.today)

            NavigationStack {
                CatalogView()
            }
            .tabItem {
                Label(AppTab.wardrobe.title, systemImage: AppTab.wardrobe.systemImage)
                    .accessibilityIdentifier(AppTab.wardrobe.accessibilityIdentifier)
            }
            .tag(AppTab.wardrobe)

            NavigationStack {
                SettingsView(
                    session: session,
                    onReplayOnboarding: onboardingState.replay
                )
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                    .accessibilityIdentifier(AppTab.settings.accessibilityIdentifier)
            }
            .tag(AppTab.settings)
        }
        .fullScreenCover(isPresented: onboardingPresentation) {
            OnboardingView(
                isReplay: onboardingState.hasCompleted,
                onComplete: completeOnboarding,
                onDismissReplay: onboardingState.dismissReplay
            )
            .interactiveDismissDisabled(!onboardingState.hasCompleted)
        }
        .task { await session.restorePreviousSignIn() }
    }

    private var selectedTab: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: selectedTabRawValue) ?? .wardrobe },
            set: { selectedTabRawValue = $0.rawValue }
        )
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { onboardingState.isPresented },
            set: { isPresented in
                if !isPresented { onboardingState.dismissReplay() }
            }
        )
    }

    private func completeOnboarding(destination: AppTab) {
        selectedTab.wrappedValue = destination
        onboardingState.complete()
    }
}
