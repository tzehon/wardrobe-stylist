import GoogleSignIn
import SwiftUI

struct ContentView: View {
    let demoMode: DemoModeController

    @State private var session: GmailSession?
    @State private var onboardingState = OnboardingState()
    @State private var devicePrivacy = DevicePrivacySettings()
    @State private var syncActivity = ReceiptSyncActivityController.shared
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
        .onOpenURL { url in
            _ = GIDSignIn.sharedInstance.handle(url)
        }
        .fullScreenCover(isPresented: onboardingPresentation) {
            OnboardingView(
                isReplay: onboardingState.hasCompleted,
                onComplete: completeOnboarding,
                onEnterDemo: enterDemoFromOnboarding,
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
            Text("Your local wardrobe, history, sync records, cached looks, and saved data-use choices were removed from this device. Google access was not revoked.")
        }
    }

    private var productionTabs: some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                TodayView(
                    privacySettings: devicePrivacy,
                    accountScope: activeAccountScope,
                    openStylingPrivacy: {
                        selectedTab.wrappedValue = .settings
                    }
                )
                .id("\(activeAccountScope.rawValue).\(localDataGeneration)")
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
            }
            .tag(AppTab.today)

            NavigationStack {
                CatalogView(accountScope: activeAccountScope)
                    .id("\(activeAccountScope.rawValue).\(localDataGeneration)")
            }
            .tabItem {
                Label(AppTab.wardrobe.title, systemImage: AppTab.wardrobe.systemImage)
                    .accessibilityIdentifier(AppTab.wardrobe.accessibilityIdentifier)
            }
            .tag(AppTab.wardrobe)

            NavigationStack {
                OutfitHistoryView(accountScope: activeAccountScope)
                    .id("\(activeAccountScope.rawValue).\(localDataGeneration)")
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
                    .accessibilityIdentifier(AppTab.history.accessibilityIdentifier)
            }
            .tag(AppTab.history)

            NavigationStack {
                if let session {
                    SettingsView(
                        session: session,
                        devicePrivacy: devicePrivacy,
                        syncActivity: syncActivity,
                        onReplayOnboarding: onboardingState.replay,
                        onEnterDemo: enterDemoFromSettings,
                        onVerifiedLocalDataDeletion: handleVerifiedLocalDataDeletion
                    )
                    .id(localDataGeneration)
                } else {
                    ProgressView("Opening Settings…")
                }
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                    .accessibilityIdentifier(AppTab.settings.accessibilityIdentifier)
            }
            .tag(AppTab.settings)
        }
        .task(id: onboardingState.hasCompleted) {
            await prepareConnectedFeatures()
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

    private var activeAccountScope: WardrobeAccountScope {
        WardrobeAccountScope(activeExternalSubject: session?.privacySubjectID)
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

    private func enterDemoFromOnboarding() {
        // Keep the real onboarding preference unchanged. First-time users return
        // to setup after the disposable tour; returning users resume normally.
        enterDemoWhenSyncIsQuiesced()
    }

    private func enterDemoFromSettings() {
        enterDemoWhenSyncIsQuiesced()
    }

    private func enterDemoWhenSyncIsQuiesced() {
        Task { @MainActor in
            _ = await syncActivity.withQuiesced {
                demoMode.enter()
            }
        }
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

    private func prepareConnectedFeatures() async {
        guard onboardingState.hasCompleted else { return }
        guard !demoMode.isActive else { return }
        await devicePrivacy.load()
        await devicePrivacy.automation.reconcile()
        guard !demoMode.isActive else { return }
        guard session == nil else { return }
        let madeSession = GmailSession()
        // Publish the signed-out/restoring session before awaiting Google. This
        // keeps all local Settings, privacy, and deletion controls available
        // even if the SDK restore is slow or needs network recovery; only the
        // optional Gmail section shows its bounded restoring state.
        session = madeSession
        await madeSession.restorePreviousSignIn()
        guard !Task.isCancelled, !demoMode.isActive else { return }
    }
}
