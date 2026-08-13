import Foundation
import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct LocalDataDeletionCoordinatorTests {
    private enum FixtureError: Error { case saveFailed }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let accountA = PrivacySubjectID.external("delete-account-a")
        let accountB = PrivacySubjectID.external("delete-account-b")

        var scopeA: WardrobeAccountScope { .external(accountA) }
        var scopeB: WardrobeAccountScope { .external(accountB) }
    }

    @Test func confirmationCopyIsExplicitAndDestructive() {
        let copy = LocalDataDeletionConfirmation()

        #expect(copy.title.localizedCaseInsensitiveContains("delete"))
        #expect(copy.message.localizedCaseInsensitiveContains("permanently"))
        #expect(copy.message.localizedCaseInsensitiveContains("does not revoke Google access"))
        #expect(copy.message.localizedCaseInsensitiveContains("cannot be undone"))
        #expect(copy.destructiveActionTitle == "Delete Local Data")
    }

    @Test func deleteAllStopsSyncDisablesWorkDeletesEveryModelAndClearsRelevantState() async throws {
        let fixture = try populatedFixture()
        var events: [String] = []
        var targetedPreferenceCalls = 0
        var targetedCacheCalls = 0
        var allPreferencePurges = 0
        var allCachePurges = 0
        var reminderTimeClears = 0
        var navigationClears = 0
        var remoteImageClears = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            stopInFlightSync: { events.append("stop"); return true },
            disableSystemWork: { events.append("disable") },
            clearPreference: { _ in targetedPreferenceCalls += 1; return true },
            clearAllPreferences: {
                events.append("all-preferences")
                allPreferencePurges += 1
                return true
            },
            clearCache: { _ in targetedCacheCalls += 1; return true },
            clearAllCaches: { allCachePurges += 1; return true },
            clearRemoteImages: { remoteImageClears += 1; return true },
            clearReminderTime: { reminderTimeClears += 1; return true },
            clearNavigationSignal: { navigationClears += 1; return true },
            save: { context in events.append("save"); try context.save() }
        )

        let succeeded = await coordinator.delete(
            scope: .all(activeExternalSubject: fixture.accountA),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        )

        #expect(succeeded)
        #expect(events.prefix(3) == ["stop", "disable", "save"])
        #expect(targetedPreferenceCalls == 0)
        #expect(targetedCacheCalls == 0)
        #expect(allPreferencePurges == 1)
        #expect(allCachePurges == 1)
        #expect(reminderTimeClears == 1)
        #expect(navigationClears == 1)
        #expect(remoteImageClears == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<WearLog>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<ProcessedGmailMessage>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<GmailSyncState>()).isEmpty)
        guard case .succeeded(let counts) = coordinator.state else {
            Issue.record("Expected verified success, got \(coordinator.state)")
            return
        }
        #expect(counts == LocalDataDeletionCounts(
            items: 3,
            outfits: 2,
            wearLogs: 2,
            processedGmailMessages: 2,
            gmailSyncStates: 2
        ))
    }

    @Test func accountDeletionPreservesSharedLocalAndOtherAccountDataAndDevicePreferences() async throws {
        let fixture = try populatedFixture()
        var clearedSubjects: [PrivacySubjectID] = []
        var clearedCaches: [WardrobeAccountScope] = []
        var deviceStateClears = 0
        var remoteImageClears = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            clearPreference: { clearedSubjects.append($0); return true },
            clearAllPreferences: {
                Issue.record("Targeted deletion must not purge all preferences")
                return false
            },
            clearCache: { clearedCaches.append($0); return true },
            clearAllCaches: {
                Issue.record("Targeted deletion must not purge all caches")
                return false
            },
            clearRemoteImages: { remoteImageClears += 1; return true },
            clearReminderTime: { deviceStateClears += 1; return true },
            clearNavigationSignal: { deviceStateClears += 1; return true }
        )

        #expect(await coordinator.delete(
            scope: .externalAccount(fixture.accountA),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ))

        let items = try fixture.context.fetch(FetchDescriptor<Item>())
        #expect(Set(items.map(\.name)) == ["Local photo", "Account B item"])
        #expect(try fixture.context.fetch(FetchDescriptor<Outfit>()).map(\.accountSubjectKey)
            == [fixture.scopeB.rawValue])
        #expect(try fixture.context.fetch(FetchDescriptor<WearLog>()).map(\.accountSubjectKey)
            == [fixture.scopeB.rawValue])
        #expect(try fixture.context.fetch(FetchDescriptor<ProcessedGmailMessage>())
            .map(\.accountSubjectKey) == [fixture.scopeB.rawValue])
        #expect(try fixture.context.fetch(FetchDescriptor<GmailSyncState>())
            .map(\.accountSubjectKey) == [fixture.scopeB.rawValue])
        #expect(clearedSubjects == [fixture.accountA])
        #expect(clearedCaches == [fixture.scopeA])
        #expect(deviceStateClears == 0)
        #expect(remoteImageClears == 1)
    }

    @Test func syncMustConfirmItStoppedBeforeAnyOtherMutation() async throws {
        let fixture = try populatedFixture()
        var disableCalls = 0
        var saveCalls = 0
        var preferenceCalls = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            stopInFlightSync: { false },
            disableSystemWork: { disableCalls += 1 },
            clearPreference: { _ in preferenceCalls += 1; return true },
            clearAllPreferences: { preferenceCalls += 1; return true },
            save: { _ in saveCalls += 1 }
        )

        #expect(await coordinator.delete(
            scope: .all(activeExternalSubject: fixture.accountA),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)

        #expect(disableCalls == 0)
        #expect(saveCalls == 0)
        #expect(preferenceCalls == 0)
        #expect(try fixture.context.fetch(FetchDescriptor<Item>()).count == 3)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected visible failure")
            return
        }
        #expect(failure.stage == .syncDidNotStop)
    }

    @Test func persistenceFailureRollsBackAndNeverReportsSuccessOrClearsPreferences() async throws {
        let fixture = try populatedFixture()
        var preferenceCalls = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            clearPreference: { _ in preferenceCalls += 1; return true },
            clearAllPreferences: { preferenceCalls += 1; return true },
            save: { _ in throw FixtureError.saveFailed }
        )

        #expect(await coordinator.delete(
            scope: .all(activeExternalSubject: fixture.accountA),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)

        #expect(preferenceCalls == 0)
        #expect(try fixture.context.fetch(FetchDescriptor<Item>()).count == 3)
        #expect(!fixture.context.hasChanges)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected visible failure")
            return
        }
        #expect(failure.stage == .persistence)
    }

    @Test func preferenceFailureAfterVerifiedModelDeletionDoesNotPretendSuccess() async throws {
        let fixture = try populatedFixture()
        var calls = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            clearAllPreferences: {
                calls += 1
                return false
            }
        )

        #expect(await coordinator.delete(
            scope: .all(activeExternalSubject: fixture.accountA),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)

        #expect(calls == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<Item>()).isEmpty)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected preference-stage failure")
            return
        }
        #expect(failure.stage == .preferences)
    }

    @Test func pendingUnrelatedContextChangesBlockDeletionWithoutRollingThemBack() async throws {
        let fixture = try populatedFixture()
        let pending = Item(name: "Unsaved", category: "top")
        fixture.context.insert(pending)
        var saveCalls = 0
        let coordinator = LocalDataDeletionCoordinator(
            modelContext: fixture.context,
            save: { _ in saveCalls += 1 }
        )

        #expect(await coordinator.delete(
            scope: .all(activeExternalSubject: nil),
            confirmedBy: LocalDataDeletionConfirmation().confirm()
        ) == false)

        #expect(saveCalls == 0)
        #expect(fixture.context.hasChanges)
        #expect(pending.modelContext === fixture.context)
        guard case .failed(let failure) = coordinator.state else {
            Issue.record("Expected persistence failure")
            return
        }
        #expect(failure.stage == .persistence)
    }

    private func populatedFixture() throws -> Fixture {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        context.autosaveEnabled = false
        let fixture = Fixture(container: container, context: context)

        let local = Item(
            name: "Local photo",
            category: "top",
            source: .photo,
            imageData: Data([1, 2, 3]),
            thumbnailData: Data([4, 5])
        )
        let itemA = Item(
            name: "Account A item",
            category: "shoe",
            source: .email,
            accountSubjectKey: fixture.scopeA.rawValue,
            imageData: Data([6, 7])
        )
        let itemB = Item(
            name: "Account B item",
            category: "bag",
            source: .email,
            accountSubjectKey: fixture.scopeB.rawValue,
            thumbnailData: Data([8, 9])
        )
        [local, itemA, itemB].forEach(context.insert)

        let outfitA = Outfit(accountSubjectKey: fixture.scopeA.rawValue, items: [local, itemA])
        let outfitB = Outfit(accountSubjectKey: fixture.scopeB.rawValue, items: [local, itemB])
        context.insert(outfitA)
        context.insert(outfitB)
        context.insert(WearLog(
            item: itemA,
            outfit: outfitA,
            accountSubjectKey: fixture.scopeA.rawValue
        ))
        context.insert(WearLog(
            item: itemB,
            outfit: outfitB,
            accountSubjectKey: fixture.scopeB.rawValue
        ))
        context.insert(ProcessedGmailMessage(
            scopedMessageKey: "a-message",
            accountSubjectKey: fixture.scopeA.rawValue,
            gmailMessageID: "message-a",
            outcome: .imported
        ))
        context.insert(ProcessedGmailMessage(
            scopedMessageKey: "b-message",
            accountSubjectKey: fixture.scopeB.rawValue,
            gmailMessageID: "message-b",
            outcome: .notFashion
        ))
        context.insert(GmailSyncState(accountSubjectKey: fixture.scopeA.rawValue))
        context.insert(GmailSyncState(accountSubjectKey: fixture.scopeB.rawValue))
        try context.save()
        return fixture
    }
}
