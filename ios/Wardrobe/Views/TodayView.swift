import SwiftData
import SwiftUI

/// Today remains local and idle until the user explicitly asks for styling.
/// Constructing this view and switching tabs never sends wardrobe data.
struct TodayView: View {
    let privacySettings: DevicePrivacySettings
    let accountScope: WardrobeAccountScope
    let openStylingPrivacy: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var storedItems: [Item]
    @State private var recommender: OutfitRecommender?
    @State private var configError: String?
    @State private var wornLookID: UUID?
    @State private var writes = WardrobeWriteCoordinator()

    private var stylingAllowed: Bool {
        privacySettings.controls.decision(for: .aiStyling).isAllowed
    }

    private var items: [Item] {
        WardrobeAccountFilter.visibleItems(from: storedItems, in: accountScope)
    }

    var body: some View {
        Group {
            if let configError {
                errorState(configError, retry: nil)
            } else if let recommender {
                content(recommender)
            } else {
                invitation
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let recommender, case .loaded = recommender.state {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await restyle(recommender) }
                    } label: {
                        Label("Restyle", systemImage: "arrow.clockwise")
                    }
                    .accessibilityHint("Sends a new compact styling request.")
                }
            }
        }
        .wardrobePersistenceAlert(writes)
    }

    private var invitation: some View {
        ContentUnavailableView {
            Label("Style your day", systemImage: "sparkles")
        } description: {
            if items.isEmpty {
                Text("Add a few wardrobe items first, then come back when you want a look.")
            } else if stylingAllowed {
                Text("When you’re ready, ask for a look. Nothing is sent just by opening Today.")
            } else {
                Text("Review AI styling data use before wardrobe details can be sent for a recommendation.")
            }
        } actions: {
            if items.isEmpty {
                EmptyView()
            } else if stylingAllowed {
                Button("Style a look") {
                    Task { await setUpAndRecommend() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Sends a compact text catalog and recent item identifiers for AI styling.")
                .accessibilityIdentifier("today.generate")
            } else {
                Button("Review AI styling data use", action: openStylingPrivacy)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("today.reviewPrivacy")
            }
        }
    }

    // MARK: - Content by state

    @ViewBuilder
    private func content(_ recommender: OutfitRecommender) -> some View {
        switch recommender.state {
        case .idle:
            invitation
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Aria is styling your day…").foregroundStyle(.secondary)
            }
        case .emptyCatalog:
            ContentUnavailableView {
                Label("Not enough to style yet", systemImage: "sparkles")
            } description: {
                Text("Add a few items to your catalog and Aria can put together a look.")
            }
        case .consentRequired:
            ContentUnavailableView {
                Label("Review data use", systemImage: "hand.raised")
            } description: {
                Text("Styling permission is required before wardrobe details are sent for a recommendation.")
            } actions: {
                Button("Review AI styling data use", action: openStylingPrivacy)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("today.reviewPrivacy")
            }
        case .failed(let message):
            errorState(message) { Task { await restyle(recommender) } }
        case .loaded(let recommendation):
            loadedLook(recommender, recommendation)
        }
    }

    private func loadedLook(
        _ recommender: OutfitRecommender,
        _ recommendation: OutfitRecommender.Recommendation
    ) -> some View {
        let look = recommendation.current
        let isWorn = wornLookID == look.id
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recommendation.occasion.capitalized)
                    .font(.title2.weight(.semibold))

                lookStrip(look)

                Text(recommendation.colorStory)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(look.rationale)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                actions(recommender, recommendation, isWorn: isWorn)
            }
            .padding()
        }
    }

    private func lookStrip(_ look: OutfitRecommender.Look) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(look.items) { item in
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
    }

    private func actions(
        _ recommender: OutfitRecommender,
        _ recommendation: OutfitRecommender.Recommendation,
        isWorn: Bool
    ) -> some View {
        VStack(spacing: 12) {
            Button {
                writes.perform(
                    operation: .recordWear,
                    write: { try recommender.wearCurrent() },
                    onSuccess: { wornLookID = recommendation.current.id }
                )
            } label: {
                Label(isWorn ? "Added to today" : "Wear this",
                      systemImage: isWorn ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorn)

            if recommendation.hasAlternates {
                Button {
                    recommender.showAnother()
                } label: {
                    Label("Show me another", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 4)
    }

    private func errorState(_ message: String, retry: (() -> Void)?) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("Couldn't style today", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Sends a new compact styling request.")
            }
        }
    }

    // MARK: - Wiring

    private func setUpAndRecommend() async {
        guard recommender == nil, configError == nil else { return }
        guard stylingAllowed else {
            openStylingPrivacy()
            return
        }
        do {
            let (baseURL, deviceToken) = try BackendConfig.load()
            let made = OutfitRecommender(
                recommendClient: RecommendClient(baseURL: baseURL, deviceToken: deviceToken),
                modelContext: modelContext,
                accountScope: accountScope
            )
            recommender = made
            await made.recommend()
        } catch {
            configError = "\(error)"
        }
    }

    private func restyle(_ recommender: OutfitRecommender) async {
        guard stylingAllowed else {
            openStylingPrivacy()
            return
        }
        wornLookID = nil
        await recommender.recommend()
    }
}
