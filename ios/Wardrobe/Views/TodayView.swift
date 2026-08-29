import SwiftData
import SwiftUI

/// Today remains local and idle until the user explicitly asks for styling.
/// Constructing this view and switching tabs never sends wardrobe data.
struct TodayView: View {
    let privacySettings: DevicePrivacySettings
    let accountScope: WardrobeAccountScope
    let openStylingPrivacy: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var storedItems: [Item]
    @State private var recommender: OutfitRecommender?
    @State private var configError: String?
    @State private var occasion = ""
    @State private var writes = WardrobeWriteCoordinator()
    @State private var activeStylingTask: Task<Void, Never>?
    @State private var activeStylingTaskID: UUID?
    @FocusState private var occasionIsFocused: Bool

    private var stylingAllowed: Bool {
        privacySettings.controls.decision(for: .aiStyling).isAllowed
    }

    private var items: [Item] {
        WardrobeAccountFilter.styleableItems(from: storedItems, in: accountScope)
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
                    .controlSize(.large)
                    .disabled(activeStylingTask != nil)
                    .accessibilityHint("Sends compact catalog details, recent item identifiers, and per-item rating summaries for AI styling.")
                    .accessibilityIdentifier("today.generate")
                }
            } else {
                Button("Review AI styling data use", action: openStylingPrivacy)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                    .controlSize(.large)
                    .accessibilityLabel("Styling in progress")
                Text("Aria is styling your day…")
                    .font(.headline)
                Text("This usually takes less than 30 seconds.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Cancel") {
                    cancelActiveStylingTask()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Stops the current styling request and keeps your occasion text.")
                .accessibilityIdentifier("today.cancel")
            }
            .multilineTextAlignment(.center)
            .padding()
            .accessibilityElement(children: .contain)
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
                    .controlSize(.large)
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

                if let message = recommendation.refreshFailureMessage {
                    refreshFailureBanner(message, recommender: recommender)
                }

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

    private func refreshFailureBanner(
        _ message: String,
        recommender: OutfitRecommender
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn't refresh this look", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") {
                requestRestyle(recommender)
            }
            .buttonStyle(.bordered)
            .disabled(activeStylingTask != nil || recommender.isRequestInFlight)
            .accessibilityHint("Sends a new compact styling request while keeping this look available.")
            .accessibilityIdentifier("today.refreshRetry")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.refreshFailure")
    }

    private func lookStrip(_ look: OutfitRecommender.Look) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(look.items) { item in
                        accessibleLookItem(item)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(look.items) { item in
                            standardLookItem(item)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Items in this look")
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
        .accessibilityLabel(accessibilityDescription(for: item))
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
        .accessibilityLabel(accessibilityDescription(for: item))
    }

    private func accessibilityDescription(for item: Item) -> String {
        [item.name, item.brand, item.category.capitalized]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
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
            .controlSize(.large)
            .accessibilityHint(isWorn
                ? "This exact look is already in today’s outfit history."
                : "Saves this look to today’s outfit history.")
            .accessibilityIdentifier("today.wear")

            if recommendation.hasAlternates {
                Button {
                    recommender.showAnother()
                } label: {
                    Label("Show me another", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Shows another saved option without sending a new network request.")
                .accessibilityIdentifier("today.alternate")
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
                    .controlSize(.large)
                    .disabled(activeStylingTask != nil)
                    .accessibilityHint("Sends a new compact styling request.")
                    .accessibilityIdentifier("today.retry")
            }
        }
    }

    // MARK: - Wiring

    private var occasionField: some View {
        TextField("Occasion (optional)", text: $occasion)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused($occasionIsFocused)
            .onSubmit { occasionIsFocused = false }
            .accessibilityHint("Adds context such as work, dinner, or travel to the next styling request.")
            .accessibilityValue(occasion.isEmpty ? "No occasion entered" : occasion)
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
#if DEBUG
        if let uiTestRecommenderFactory = TodayProcessRelaunchUITestRuntime.recommenderFactory {
            do {
                let made = try uiTestRecommenderFactory(modelContext, accountScope)
                guard !Task.isCancelled else { return }
                recommender = made
                await made.recommend(occasion: occasion)
            } catch {
                guard !Task.isCancelled else { return }
                configError = "The styling service isn’t configured for this build. Please try again after updating the app."
            }
            return
        }
#endif
        do {
            let baseURL = try BackendConfig.load()
            guard !Task.isCancelled else { return }
            let made = OutfitRecommender(
                recommendClient: RecommendClient(baseURL: baseURL),
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
