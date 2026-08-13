import SwiftUI

struct ContentView: View {
    @State private var session = GmailSession()
    @State private var onboardingState = OnboardingState()
    @State private var devicePrivacy = DevicePrivacySettings()
    @SceneStorage("com.tth.Wardrobe.selectedTab")
    private var selectedTabRawValue = AppTab.wardrobe.rawValue

    var body: some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                TodayView(
                    privacySettings: devicePrivacy,
                    openStylingPrivacy: {
                        selectedTab.wrappedValue = .settings
                    }
                )
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
                    devicePrivacy: devicePrivacy,
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
        .task {
            await devicePrivacy.load()
            await session.restorePreviousSignIn()
        }
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
