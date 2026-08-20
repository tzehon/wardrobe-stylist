import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    let isReplay: Bool
    let onComplete: (AppTab) -> Void
    let onEnterDemo: () -> Void
    let onDismissReplay: () -> Void

    @State private var isInstallingSamples = false
    @State private var sampleError: SampleWardrobeError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    benefits
                    actions
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                if isReplay {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", action: onDismissReplay)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityHint("Returns to Settings without changing your choices.")
                            .accessibilityIdentifier("onboarding.close")
                    }
                }
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
    }

    private var hero: some View {
        VStack(spacing: 16) {
            Image("LaunchMark")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .accessibilityHidden(true)

            Text("WARDROBE STYLIST")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Wardrobe Stylist")

            Text(isReplay ? "A quick tour" : "Your wardrobe, your way")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Add pieces yourself and browse them anytime. AI styling is optional and available whenever you choose it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.hero")
    }

    private var benefits: some View {
        VStack(spacing: 12) {
            benefit(
                title: "Start locally",
                detail: "Your wardrobe stays on this device and needs no account.",
                symbol: "iphone",
                accessibilityIdentifier: "onboarding.benefit.local"
            )
            benefit(
                title: "Build your catalog",
                detail: "Add photos or details, then search and organize every piece.",
                symbol: "square.grid.2x2",
                accessibilityIdentifier: "onboarding.benefit.catalog"
            )
            benefit(
                title: "Choose connected features",
                detail: "Review data use before enabling AI styling or reminders.",
                symbol: "hand.raised",
                accessibilityIdentifier: "onboarding.benefit.connected"
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func benefit(
        title: String,
        detail: String,
        symbol: String,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                onComplete(.wardrobe)
            } label: {
                Text("Start with my wardrobe")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Opens an empty local wardrobe. No account or network connection is required.")
            .accessibilityIdentifier("onboarding.startLocal")

            sampleChoice
            demoChoice

            Button("Set up AI styling") {
                onComplete(.settings)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .accessibilityHint("Opens Settings. AI styling is optional.")
            .accessibilityIdentifier("onboarding.openStylingSettings")

            Label("Local browsing and manual item capture never require an account.", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
        }
    }

    private var sampleChoice: some View {
        VStack(spacing: 6) {
            Button(action: installSamples) {
                HStack {
                    if isInstallingSamples { ProgressView() }
                    Text(isInstallingSamples ? "Adding samples…" : "Explore with sample items")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isInstallingSamples)
            .accessibilityLabel(isInstallingSamples ? "Adding sample items" : "Explore with sample items")
            .accessibilityHint("Adds four clearly labeled sample pieces to your local wardrobe. You can remove them later in Settings.")
            .accessibilityIdentifier("onboarding.installSamples")

            Text("Sample pieces stay in your local wardrobe until you remove them in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var demoChoice: some View {
        VStack(spacing: 6) {
            Button(action: onEnterDemo) {
                Label("Try the offline demo", systemImage: "sparkles.rectangle.stack")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Opens a fictional, disposable wardrobe without network features.")
            .accessibilityIdentifier("onboarding.enterDemo")

            Text("Demo uses fictional data and discards every change when you exit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func installSamples() {
        guard !isInstallingSamples else { return }
        isInstallingSamples = true
        defer { isInstallingSamples = false }
        do {
            try SampleWardrobeSeeder(modelContext: modelContext).seed()
            onComplete(.wardrobe)
        } catch let error as SampleWardrobeError {
            sampleError = error
        } catch {
            sampleError = SampleWardrobeError(diagnostic: String(describing: error))
        }
    }
}
