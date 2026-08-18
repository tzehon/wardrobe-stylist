#if DEBUG
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// An explicit, Debug-only launch policy for end-to-end privacy UI tests.
///
/// The production target contains this source so XCUITest can exercise the same
/// Settings hierarchy that ships, but the compiler removes the entire harness
/// from Release builds. Normal Debug launches also remain production-like:
/// only the exact private argument below enables the isolated experience.
enum ConnectedUITestLaunchPolicy {
    static let argument = "--wardrobe-ui-testing-connected"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

/// Uses the ordinary local-first shell with a disposable in-memory store so
/// onboarding UI coverage never reads or migrates a developer's real data.
enum LocalUITestLaunchPolicy {
    static let argument = "--wardrobe-ui-testing-local"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

/// Owns every dependency used by the deterministic connected-account UI flow.
/// The SwiftData container and privacy stores exist in memory only. Google is
/// represented by an app-owned fake identity, while Gmail transport traps at
/// the boundary instead of constructing URLSession or contacting a backend.
@MainActor
final class ConnectedUITestExperience {
    let container: ModelContainer
    let session: GmailSession
    let devicePrivacy: DevicePrivacySettings
    let syncActivity = ReceiptSyncActivityController()
    let serverIdentityDeletion: any ServerIdentityDeleting = ConnectedUITestServerIdentityDeletion()

    private let privacyStore = InMemoryUITestPrivacyPreferencesStore()
    private let reminderTimeStore = InMemoryUITestReminderTimeStore()
    private let subjectID = PrivacySubjectID.external("fictional-ui-test-account")
    private let networkGuard: ConnectedUITestNetworkGuard

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        let networkGuard = ConnectedUITestNetworkGuard()
        self.networkGuard = networkGuard

        let identity = GoogleSignInIdentity(
            stableUserID: "fictional-ui-test-account",
            email: "reviewer@example.invalid",
            grantedScopes: Set(GmailScope.requested)
        )
        let provider = ConnectedUITestGoogleProvider(identity: identity)
        session = GmailSession(
            provider: provider,
            makeClient: {
                GmailReadOnlyClient(
                    transport: DenyNetworkUITestGmailTransport(guard: networkGuard),
                    auth: DenyNetworkUITestGmailAuth(guard: networkGuard)
                )
            }
        )

        let deviceControls = PrivacyControls(
            subjectID: .deviceLocal,
            store: privacyStore
        )
        let deviceAutomation = PrivacyAutomationCoordinator(
            controls: deviceControls,
            scheduleBackground: {},
            cancelBackground: {},
            enableReminder: { _ in true },
            disableReminder: {},
            reminderTimeStore: reminderTimeStore
        )
        devicePrivacy = DevicePrivacySettings(
            controls: deviceControls,
            automation: deviceAutomation
        )

        try seedFictionalLocalData()
    }

    func prepare() async {
        await devicePrivacy.load()
        await session.restorePreviousSignIn()
    }

    func makeGmailPrivacySettings() -> GmailPrivacySettings {
        let controls = PrivacyControls(subjectID: subjectID, store: privacyStore)
        let automation = PrivacyAutomationCoordinator(
            controls: controls,
            scheduleBackground: {},
            cancelBackground: {},
            enableReminder: { _ in true },
            disableReminder: {},
            reminderTimeStore: reminderTimeStore
        )
        return GmailPrivacySettings(
            subjectID: subjectID,
            store: privacyStore,
            devicePrivacy: devicePrivacy,
            controls: controls,
            automation: automation
        )
    }

    var networkBoundaryStatus: String {
        networkGuard.attemptCount == 0
            ? "Network boundary: 0 requests attempted"
            : "Network boundary violation: \(networkGuard.attemptCount) requests attempted"
    }

    private func seedFictionalLocalData() throws {
        let context = ModelContext(container)
        let accountKey = WardrobeAccountScope.external(
            .external("fictional-ui-test-account")
        ).rawValue

        context.insert(Item(
            id: UUID(uuidString: "C011EC7E-D000-4000-8000-000000000001")!,
            name: "Fictional Receipt Jacket",
            category: "outerwear",
            subcategory: "jacket",
            brand: "Example Atelier",
            colors: ["navy"],
            material: "cotton twill",
            styleNotes: "UI-test-only fictional purchase.",
            source: .email,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            sourceMsgId: "fictional-message-id",
            imageURL: nil,
            accountSubjectKey: accountKey,
            reviewState: .accepted
        ))
        context.insert(Item(
            id: UUID(uuidString: "C011EC7E-D000-4000-8000-000000000002")!,
            name: "Fictional Local Tee",
            category: "top",
            brand: "Example Goods",
            colors: ["white"],
            source: .manual,
            reviewState: .accepted
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
                VStack(spacing: 0) {
                    Text(experience.networkBoundaryStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("uiTest.connected.networkStatus")
                    SettingsView(
                        session: experience.session,
                        devicePrivacy: experience.devicePrivacy,
                        syncActivity: experience.syncActivity,
                        onReplayOnboarding: {},
                        onEnterDemo: {},
                        onVerifiedLocalDataDeletion: verifiedLocalDataWasDeleted,
                        makeGmailPrivacySettings: { _ in
                            experience.makeGmailPrivacySettings()
                        },
                        serverIdentityDeletion: experience.serverIdentityDeletion
                    )
                    .id(localDataGeneration)
                }
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
            Text("Your local wardrobe, history, sync records, cached looks, and saved data-use choices were removed from this device. Google access was not revoked.")
        }
        .accessibilityIdentifier("uiTest.connected.root")
    }

    private func verifiedLocalDataWasDeleted() {
        localDataGeneration &+= 1
        showingLocalDataDeleted = true
    }
}

@MainActor
private final class ConnectedUITestGoogleProvider: GoogleSignInProviding {
    private let identity: GoogleSignInIdentity
    private var isConnected = true

    init(identity: GoogleSignInIdentity) {
        self.identity = identity
    }

    var hasPreviousSignIn: Bool { isConnected }

    func restorePreviousSignIn() async throws -> GoogleSignInIdentity {
        guard isConnected else { throw GoogleSignInProviderFailure.noPreviousSignIn }
        return identity
    }

    func signIn(
        presenting viewController: UIViewController,
        additionalScopes: [String]
    ) async throws -> GoogleSignInIdentity {
        _ = viewController
        _ = additionalScopes
        guard isConnected else { throw GoogleSignInProviderFailure.unavailable }
        return identity
    }

    func signOut() {
        isConnected = false
    }

    func disconnect() async throws {
        isConnected = false
    }
}

private struct DenyNetworkUITestGmailTransport: GmailTransport {
    let `guard`: ConnectedUITestNetworkGuard

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        _ = request
        return try `guard`.block()
    }
}

private struct DenyNetworkUITestGmailAuth: GmailAuth {
    let `guard`: ConnectedUITestNetworkGuard

    func accessToken() async throws -> String {
        return try `guard`.block()
    }
}

private enum ConnectedUITestNetworkFailure: Error {
    case blocked
}

private actor ConnectedUITestServerIdentityDeletion: ServerIdentityDeleting {
    func deleteServerIdentity() -> ServerIdentityDeletionResult {
        .deleted
    }
}

private final class ConnectedUITestNetworkGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0

    var attemptCount: Int {
        lock.withLock { attempts }
    }

    func block<Return>() throws -> Return {
        lock.withLock { attempts += 1 }
        throw ConnectedUITestNetworkFailure.blocked
    }
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
