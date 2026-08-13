import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    let isReplay: Bool
    let onComplete: (AppTab) -> Void
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
            Image(systemName: "tshirt.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(isReplay ? "A quick tour" : "Your wardrobe, your way")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Add pieces yourself and browse them anytime. Gmail import and AI styling are optional features you can choose later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(spacing: 12) {
            benefit(
                title: "Start locally",
                detail: "Your wardrobe works without a Google account.",
                symbol: "iphone"
            )
            benefit(
                title: "Build your catalog",
                detail: "Add photos or details, then search and organize every piece.",
                symbol: "square.grid.2x2"
            )
            benefit(
                title: "Choose connected features",
                detail: "Review data use before enabling Gmail import or AI styling.",
                symbol: "hand.raised"
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func benefit(title: String, detail: String, symbol: String) -> some View {
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
            .accessibilityIdentifier("onboarding.startLocal")

            Button(action: installSamples) {
                HStack {
                    if isInstallingSamples { ProgressView() }
                    Text(isInstallingSamples ? "Adding samples…" : "Explore with sample items")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(isInstallingSamples)
            .accessibilityIdentifier("onboarding.installSamples")

            Button("Set up Gmail import") {
                onComplete(.settings)
            }
            .font(.subheadline)
            .accessibilityHint("Opens Settings. Gmail import is optional.")
            .accessibilityIdentifier("onboarding.openGmailSettings")
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
