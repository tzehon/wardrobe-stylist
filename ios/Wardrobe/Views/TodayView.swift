import SwiftData
import SwiftUI

/// Phase 5: the "Today" screen. Asks Aria for one wearable, non-repeating look
/// from the catalog, renders it with a rationale, lets the user shuffle to an
/// alternate, and records "Wear this" (→ Outfit + WearLog, feeding anti-repeat).
///
/// The recommender is built lazily on first appear — it needs a configured
/// backend, mirroring how `ContentView` builds the receipt pipeline.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recommender: OutfitRecommender?
    @State private var configError: String?
    @State private var wornLookID: UUID?

    var body: some View {
        Group {
            if let configError {
                errorState(configError, retry: nil)
            } else if let recommender {
                content(recommender)
            } else {
                ProgressView()
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
                }
            }
        }
        .task { await setUpAndRecommend() }
    }

    // MARK: - Content by state

    @ViewBuilder
    private func content(_ recommender: OutfitRecommender) -> some View {
        switch recommender.state {
        case .idle, .loading:
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
                recommender.wearCurrent()
                wornLookID = recommendation.current.id
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
            }
        }
    }

    // MARK: - Wiring

    private func setUpAndRecommend() async {
        guard recommender == nil, configError == nil else { return }
        do {
            let (baseURL, deviceToken) = try BackendConfig.load()
            let made = OutfitRecommender(
                recommendClient: RecommendClient(baseURL: baseURL, deviceToken: deviceToken),
                modelContext: modelContext
            )
            recommender = made
            await made.recommend()
        } catch {
            configError = "\(error)"
        }
    }

    private func restyle(_ recommender: OutfitRecommender) async {
        wornLookID = nil
        await recommender.recommend()
    }
}
