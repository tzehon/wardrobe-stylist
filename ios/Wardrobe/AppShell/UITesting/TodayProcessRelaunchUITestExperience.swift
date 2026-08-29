#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// Launches the production Today and History views with fictional local data,
/// an isolated durable cache, and a deterministic network boundary. This lets
/// UI automation cross a real process termination without touching the user's
/// production store, App Attest identity, or backend.
enum TodayProcessRelaunchUITestLaunchPolicy {
    static let argument = "--wardrobe-ui-testing-today-relaunch"
    static let offlineArgument = "--wardrobe-ui-testing-today-offline"
    static let resetArgument = "--wardrobe-ui-testing-today-reset"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

@MainActor
enum TodayProcessRelaunchUITestRuntime {
    static var recommenderFactory: ((ModelContext, WardrobeAccountScope) throws -> OutfitRecommender)?
}

@MainActor
final class TodayProcessRelaunchUITestExperience {
    enum Phase: Equatable {
        case online
        case offline
    }

    nonisolated static let itemA = UUID(
        uuidString: "A0140000-0000-4000-8000-000000000001"
    )!
    nonisolated static let itemB = UUID(
        uuidString: "A0140000-0000-4000-8000-000000000002"
    )!
    nonisolated static let itemC = UUID(
        uuidString: "A0140000-0000-4000-8000-000000000003"
    )!

    let container: ModelContainer
    let devicePrivacy: DevicePrivacySettings

    private static let defaultsSuite = "com.tth.Wardrobe.uiTests.todayRelaunch"
    private let phase: Phase
    private let dailyLookCache: UserDefaultsDailyLookCache
    private let privacyStore = TodayRelaunchUITestPrivacyStore()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        phase = arguments.contains(TodayProcessRelaunchUITestLaunchPolicy.offlineArgument)
            ? .offline
            : .online

        guard let defaults = UserDefaults(suiteName: Self.defaultsSuite) else {
            preconditionFailure("Could not create the Today relaunch UI-test defaults suite.")
        }
        if arguments.contains(TodayProcessRelaunchUITestLaunchPolicy.resetArgument) {
            defaults.removePersistentDomain(forName: Self.defaultsSuite)
        }
        dailyLookCache = UserDefaultsDailyLookCache(defaults: defaults)
        TodayRelaunchUITestNetworkCounter.shared.reset()

        container = try ModelContainerFactory.makeInMemory()
        let controls = PrivacyControls(subjectID: .deviceLocal, store: privacyStore)
        let automation = PrivacyAutomationCoordinator(
            controls: controls,
            enableReminder: { _ in true },
            disableReminder: {}
        )
        devicePrivacy = DevicePrivacySettings(controls: controls, automation: automation)
        try seedFictionalCatalog()
        TodayProcessRelaunchUITestRuntime.recommenderFactory = makeRecommender
    }

    func prepare() async {
        await devicePrivacy.load()
        _ = await devicePrivacy.grantStyling()
    }

    func makeRecommender(
        modelContext: ModelContext,
        accountScope: WardrobeAccountScope
    ) -> OutfitRecommender {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TodayRelaunchUITestURLProtocol.self]
        let host = phase == .offline ? "offline.ui-test.invalid" : "online.ui-test.invalid"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return OutfitRecommender(
            recommendClient: RecommendClient(
                baseURL: URL(string: "https://\(host)")!,
                authorization: StaticBackendAuthorization(token: "ui-test-installation-session"),
                session: URLSession(configuration: configuration)
            ),
            modelContext: modelContext,
            privacyGate: TodayRelaunchUITestAllowPrivacyGate(),
            privacySubjectID: .deviceLocal,
            accountScope: accountScope,
            dailyLookCache: dailyLookCache,
            calendar: calendar,
            now: { Date(timeIntervalSince1970: 1_788_004_800) }
        )
    }

    var networkRequestCount: Int {
        TodayRelaunchUITestNetworkCounter.shared.value
    }

    private func seedFictionalCatalog() throws {
        let context = ModelContext(container)
        context.insert(Item(
            id: Self.itemA,
            name: "Fictional Navy Overshirt",
            category: "top",
            brand: "Example Atelier",
            colors: ["navy"],
            material: "cotton",
            source: .manual
        ))
        context.insert(Item(
            id: Self.itemB,
            name: "Fictional Stone Trousers",
            category: "bottom",
            brand: "Example Goods",
            colors: ["stone"],
            material: "linen blend",
            source: .manual
        ))
        context.insert(Item(
            id: Self.itemC,
            name: "Fictional Brown Loafers",
            category: "shoe",
            brand: "Example Works",
            colors: ["brown"],
            material: "leather",
            source: .manual
        ))
        try context.save()
    }
}

struct TodayProcessRelaunchUITestRootView: View {
    let experience: TodayProcessRelaunchUITestExperience

    @State private var isPrepared = false
    @State private var selectedTab: AppTab = .today
    @State private var networkRequestCount = 0

    var body: some View {
        Group {
            if isPrepared {
                VStack(spacing: 0) {
                    Text("UI test network requests: \(networkRequestCount)")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(.thinMaterial)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("UI test network requests: \(networkRequestCount)")
                        .accessibilityIdentifier("uiTest.today.networkRequestCount")
                    tabs
                }
            } else {
                ProgressView("Opening isolated Today test…")
            }
        }
        .modelContainer(experience.container)
        .task {
            await experience.prepare()
            networkRequestCount = experience.networkRequestCount
            isPrepared = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                networkRequestCount = experience.networkRequestCount
            }
        }
        .accessibilityIdentifier("uiTest.today.root")
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(
                    privacySettings: experience.devicePrivacy,
                    accountScope: .deviceLocal,
                    openStylingPrivacy: {}
                )
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
            }
            .tag(AppTab.today)

            NavigationStack {
                CatalogView(accountScope: .deviceLocal)
            }
            .tabItem {
                Label(AppTab.wardrobe.title, systemImage: AppTab.wardrobe.systemImage)
                    .accessibilityIdentifier(AppTab.wardrobe.accessibilityIdentifier)
            }
            .tag(AppTab.wardrobe)

            NavigationStack {
                OutfitHistoryView(accountScope: .deviceLocal)
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
                    .accessibilityIdentifier(AppTab.history.accessibilityIdentifier)
            }
            .tag(AppTab.history)

        }
    }
}

private actor TodayRelaunchUITestPrivacyStore: PrivacyPreferencesStoring {
    private var preferences = AccountPrivacyPreferences.defaultDeny

    func load(for subjectID: PrivacySubjectID) -> PrivacyPreferencesLoadResult {
        .loaded(preferences)
    }

    func save(
        _ preferences: AccountPrivacyPreferences,
        for subjectID: PrivacySubjectID
    ) throws {
        self.preferences = preferences
    }

    func remove(for subjectID: PrivacySubjectID) {
        preferences = .defaultDeny
    }
}

private struct TodayRelaunchUITestAllowPrivacyGate: PrivacyGateChecking {
    func decision(
        for capability: PrivacyCapability,
        subjectID: PrivacySubjectID
    ) -> PrivacyGateDecision {
        .allowed
    }
}

private final class TodayRelaunchUITestNetworkCounter: @unchecked Sendable {
    static let shared = TodayRelaunchUITestNetworkCounter()

    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }

    func reset() {
        lock.withLock { count = 0 }
    }
}

private final class TodayRelaunchUITestURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        TodayRelaunchUITestNetworkCounter.shared.increment()
        guard request.url?.host == "online.ui-test.invalid",
              request.url?.path == "/recommend",
              request.httpMethod == "POST" else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let body = """
        {
          "occasion": "weekday layers",
          "color_story": "navy, stone, and warm brown",
          "rationale": "A calm fictional combination for deterministic UI testing.",
          "item_ids": [
            "\(TodayProcessRelaunchUITestExperience.itemA.uuidString)",
            "\(TodayProcessRelaunchUITestExperience.itemB.uuidString)",
            "\(TodayProcessRelaunchUITestExperience.itemC.uuidString)"
          ],
          "alternates": [],
          "usage": {
            "input_tokens": 100,
            "output_tokens": 40,
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0
          }
        }
        """
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
#endif
