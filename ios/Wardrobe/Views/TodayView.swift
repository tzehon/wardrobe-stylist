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
    @State private var occasion = ""
    @State private var writes = WardrobeWriteCoordinator()
    @State private var activeStylingTask: Task<Void, Never>?
    @State private var activeStylingTaskID: UUID?

    private var stylingAllowed: Bool {
        privacySettings.controls.decision(for: .aiStyling).isAllowed
    }

    private var items: [Item] {
        WardrobeAccountFilter.visibleItems(from: storedItems, in: accountScope)
    }

    var body: some View {
        Group {
            if let configError {
                errorState(configError) {
                    self.configError = nil
                    requestInitialLook()
                }
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
                        requestRestyle(recommender)
                    } label: {
                        Label("Restyle", systemImage: "arrow.clockwise")
                    }
                    .accessibilityHint("Sends a new compact styling request.")
                    .disabled(activeStylingTask != nil || recommender.isRequestInFlight)
                    .accessibilityIdentifier("today.restyle")
                }
            }
        }
        .wardrobePersistenceAlert(writes)
        .onDisappear(perform: cancelActiveStylingTask)
        .onChange(of: accountScope) { _, _ in
            resetForAccountScopeChange()
        }
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
                VStack(spacing: 12) {
                    occasionField
                    Button("Style a look") {
                        requestInitialLook()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(activeStylingTask != nil)
                    .accessibilityHint("Sends a compact text catalog and recent item identifiers for AI styling.")
                    .accessibilityIdentifier("today.generate")
                }
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
            errorState(message) { requestRestyle(recommender) }
        case .loaded(let recommendation):
            loadedLook(recommender, recommendation)
        }
    }

    private func loadedLook(
        _ recommender: OutfitRecommender,
        _ recommendation: OutfitRecommender.Recommendation
    ) -> some View {
        let look = recommendation.current
        let isWorn = recommendation.wasWornToday
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recommendation.occasion.capitalized)
                    .font(.title2.weight(.semibold))

                Label(
                    recommendation.isCached
                        ? "Look details saved earlier today · available offline"
                        : "Styled \(recommendation.generatedAt.formatted(date: .omitted, time: .shortened))",
                    systemImage: recommendation.isCached ? "clock.badge.checkmark" : "sparkles"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                lookStrip(look)

                Text(recommendation.colorStory)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(look.rationale)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Context for your next restyle")
                        .font(.subheadline.weight(.semibold))
                    occasionField
                }
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
                    write: { _ = try recommender.wearCurrent() }
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
                    .disabled(activeStylingTask != nil)
                    .accessibilityHint("Sends a new compact styling request.")
            }
        }
    }

    // MARK: - Wiring

    private var occasionField: some View {
        TextField("Occasion (optional)", text: $occasion)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .accessibilityHint("Adds context such as work, dinner, or travel to the next styling request.")
            .accessibilityIdentifier("today.occasion")
            .onChange(of: occasion) { _, newValue in
                let limited = StylingOccasion.limited(newValue)
                if limited != newValue { occasion = limited }
            }
    }

    private var requestedOccasion: String? {
        StylingOccasion.requestValue(occasion)
    }

    private func requestInitialLook() {
        let occasion = requestedOccasion
        startStylingTask {
            await setUpAndRecommend(occasion: occasion)
        }
    }

    private func requestRestyle(_ recommender: OutfitRecommender) {
        let occasion = requestedOccasion
        startStylingTask {
            await restyle(recommender, occasion: occasion)
        }
    }

    private func startStylingTask(
        operation: @escaping @MainActor () async -> Void
    ) {
        guard activeStylingTask == nil else { return }
        let taskID = UUID()
        activeStylingTaskID = taskID
        activeStylingTask = Task { @MainActor in
            defer { finishStylingTask(taskID) }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    private func finishStylingTask(_ taskID: UUID) {
        guard activeStylingTaskID == taskID else { return }
        activeStylingTask = nil
        activeStylingTaskID = nil
    }

    private func cancelActiveStylingTask() {
        activeStylingTask?.cancel()
    }

    private func resetForAccountScopeChange() {
        activeStylingTask?.cancel()
        activeStylingTask = nil
        activeStylingTaskID = nil
        recommender = nil
        configError = nil
        occasion = ""
    }

    private func setUpAndRecommend(occasion: String?) async {
        guard stylingAllowed else {
            openStylingPrivacy()
            return
        }
        if let recommender {
            await recommender.recommend(occasion: occasion)
            return
        }
        do {
            let (baseURL, deviceToken) = try BackendConfig.load()
            guard !Task.isCancelled else { return }
            let made = OutfitRecommender(
                recommendClient: RecommendClient(baseURL: baseURL, deviceToken: deviceToken),
                modelContext: modelContext,
                privacySubjectID: .deviceLocal,
                accountScope: accountScope,
                dailyLookCache: UserDefaultsDailyLookCache()
            )
            recommender = made
            await made.recommend(occasion: occasion)
        } catch {
            guard !Task.isCancelled else { return }
            configError = "The styling service isn’t configured for this build. Please try again after updating the app."
        }
    }

    private func restyle(_ recommender: OutfitRecommender, occasion: String?) async {
        guard stylingAllowed else {
            openStylingPrivacy()
            return
        }
        await recommender.recommend(occasion: occasion, refresh: true)
    }
}
