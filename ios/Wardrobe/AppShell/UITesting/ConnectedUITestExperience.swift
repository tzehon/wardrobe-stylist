#if DEBUG
import SwiftData
import SwiftUI

/// Debug-only, in-memory Settings harness for privacy and deletion UI tests.
enum ConnectedUITestLaunchPolicy {
    static let argument = "--wardrobe-ui-testing-connected"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

enum LocalUITestLaunchPolicy {
    static let argument = "--wardrobe-ui-testing-local"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

@MainActor
final class ConnectedUITestExperience {
    let container: ModelContainer
    let devicePrivacy: DevicePrivacySettings
    let serverIdentityDeletion: any ServerIdentityDeleting = ConnectedUITestServerIdentityDeletion()

    private let privacyStore = InMemoryUITestPrivacyPreferencesStore()
    private let reminderTimeStore = InMemoryUITestReminderTimeStore()

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        let controls = PrivacyControls(subjectID: .deviceLocal, store: privacyStore)
        let automation = PrivacyAutomationCoordinator(
            controls: controls,
            enableReminder: { _ in true },
            disableReminder: {},
            reminderTimeStore: reminderTimeStore
        )
        devicePrivacy = DevicePrivacySettings(controls: controls, automation: automation)
        try seedFictionalLocalData()
    }

    func prepare() async {
        await devicePrivacy.load()
    }

    private func seedFictionalLocalData() throws {
        let context = ModelContext(container)
        context.insert(Item(
            id: UUID(uuidString: "C011EC7E-D000-4000-8000-000000000001")!,
            name: "Fictional Navy Jacket",
            category: "outerwear",
            subcategory: "jacket",
            brand: "Example Atelier",
            colors: ["navy"],
            material: "cotton twill",
            styleNotes: "UI-test-only fictional item.",
            source: .manual,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        context.insert(Item(
            id: UUID(uuidString: "C011EC7E-D000-4000-8000-000000000002")!,
            name: "Fictional Local Tee",
            category: "top",
            brand: "Example Goods",
            colors: ["white"],
            source: .manual
        ))
        try context.save()
    }
}

struct ConnectedUITestRootView: View {
    let experience: ConnectedUITestExperience

    @State private var isPrepared = false
    @State private var localDataGeneration = 0
    @State private var showingLocalDataDeleted = false

    var body: some View {
        NavigationStack {
            if isPrepared {
                SettingsView(
                    devicePrivacy: experience.devicePrivacy,
                    onReplayOnboarding: {},
                    onEnterDemo: {},
                    onVerifiedLocalDataDeletion: verifiedLocalDataWasDeleted,
                    serverIdentityDeletion: experience.serverIdentityDeletion
                )
                .id(localDataGeneration)
            } else {
                ProgressView("Opening isolated UI test…")
            }
        }
        .modelContainer(experience.container)
        .task {
            await experience.prepare()
            isPrepared = true
        }
        .alert("Local Data Deleted", isPresented: $showingLocalDataDeleted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your local wardrobe, history, cached looks, reminder, and saved data-use choices were removed from this device.")
        }
        .accessibilityIdentifier("uiTest.connected.root")
    }

    private func verifiedLocalDataWasDeleted() {
        localDataGeneration &+= 1
        showingLocalDataDeleted = true
    }
}

private actor ConnectedUITestServerIdentityDeletion: ServerIdentityDeleting {
    func deleteServerIdentity() -> ServerIdentityDeletionResult { .deleted }
}

private actor InMemoryUITestPrivacyPreferencesStore: PrivacyPreferencesStoring {
    private var records: [PrivacySubjectID: AccountPrivacyPreferences] = [:]

    func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult {
        .loaded(records[subjectID] ?? .defaultDeny)
    }

    func save(
        _ preferences: AccountPrivacyPreferences,
        for subjectID: PrivacySubjectID
    ) async throws {
        records[subjectID] = preferences
    }

    func remove(for subjectID: PrivacySubjectID) async {
        records[subjectID] = nil
    }
}

@MainActor
private final class InMemoryUITestReminderTimeStore: DailyReminderTimeStoring {
    private var time = DailyReminderTime.defaultMorning

    func load() -> DailyReminderTime { time }
    func save(_ time: DailyReminderTime) -> Bool {
        self.time = time
        return true
    }
    func remove() -> Bool {
        time = .defaultMorning
        return true
    }
}
#endif
