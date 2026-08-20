import SwiftUI

struct ContentView: View {
    let demoMode: DemoModeController

    @State private var onboardingState = OnboardingState()
    @State private var devicePrivacy = DevicePrivacySettings()
    @State private var localDataGeneration = 0
    @State private var showingLocalDataDeleted = false
    @SceneStorage("com.tth.Wardrobe.selectedTab")
    private var selectedTabRawValue = AppTab.wardrobe.rawValue

    var body: some View {
        Group {
            if let demoSession = demoMode.session {
                DemoModeRootView(
                    session: demoSession,
                    onReset: { _ = demoMode.reset() },
                    onExit: demoMode.exit
                )
                .id(ObjectIdentifier(demoSession))
            } else {
                productionTabs
            }
        }
        .fullScreenCover(isPresented: onboardingPresentation) {
            OnboardingView(
                isReplay: onboardingState.hasCompleted,
                onComplete: completeOnboarding,
                onEnterDemo: { _ = demoMode.enter() },
                onDismissReplay: onboardingState.dismissReplay
            )
            .interactiveDismissDisabled(!onboardingState.hasCompleted)
        }
        .alert(
            "Couldn’t Open Demo",
            isPresented: demoFailurePresentation,
            presenting: demoMode.failure
        ) { _ in
            Button("OK", role: .cancel) { demoMode.clearFailure() }
        } message: { _ in
            Text(DemoModeFailure.userMessage)
        }
        .alert("Local Data Deleted", isPresented: $showingLocalDataDeleted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your local wardrobe, history, cached looks, reminder, and saved data-use choices were removed from this device.")
        }
    }

    private var productionTabs: some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                TodayView(
                    privacySettings: devicePrivacy,
                    accountScope: .deviceLocal,
                    openStylingPrivacy: { selectedTab.wrappedValue = .settings }
                )
                .id(localDataGeneration)
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
            }
            .tag(AppTab.today)

            NavigationStack {
                CatalogView(accountScope: .deviceLocal)
                    .id(localDataGeneration)
            }
            .tabItem {
                Label(AppTab.wardrobe.title, systemImage: AppTab.wardrobe.systemImage)
                    .accessibilityIdentifier(AppTab.wardrobe.accessibilityIdentifier)
            }
            .tag(AppTab.wardrobe)

            NavigationStack {
                OutfitHistoryView(accountScope: .deviceLocal)
                    .id(localDataGeneration)
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
                    .accessibilityIdentifier(AppTab.history.accessibilityIdentifier)
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView(
                    devicePrivacy: devicePrivacy,
                    onReplayOnboarding: onboardingState.replay,
                    onEnterDemo: { _ = demoMode.enter() },
                    onVerifiedLocalDataDeletion: handleVerifiedLocalDataDeletion
                )
                .id(localDataGeneration)
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                    .accessibilityIdentifier(AppTab.settings.accessibilityIdentifier)
            }
            .tag(AppTab.settings)
        }
        .task(id: onboardingState.hasCompleted) {
            guard onboardingState.hasCompleted, !demoMode.isActive else { return }
            await devicePrivacy.load()
            await devicePrivacy.automation.reconcile()
            consumePendingTodayDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wardrobeNavigateToToday)) { _ in
            consumePendingTodayDestination()
            selectedTab.wrappedValue = .today
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
            get: { !demoMode.isActive && onboardingState.isPresented },
            set: { isPresented in
                if !isPresented { onboardingState.dismissReplay() }
            }
        )
    }

    private var demoFailurePresentation: Binding<Bool> {
        Binding(
            get: { demoMode.failure != nil },
            set: { isPresented in
                if !isPresented { demoMode.clearFailure() }
            }
        )
    }

    private func completeOnboarding(destination: AppTab) {
        selectedTab.wrappedValue = destination
        onboardingState.complete()
    }

    private func consumePendingTodayDestination() {
        guard UserDefaultsAppNavigationSignalStore().consumeTodayDestination() else { return }
        selectedTab.wrappedValue = .today
    }

    private func handleVerifiedLocalDataDeletion() {
        devicePrivacy = DevicePrivacySettings()
        localDataGeneration &+= 1
        showingLocalDataDeleted = true
    }
}
