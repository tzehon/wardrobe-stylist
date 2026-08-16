import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct BackgroundSyncControllerTests {
    private struct StubGate: PrivacyGateChecking {
        let decisions: DecisionSequence

        func decision(
            for capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) async -> PrivacyGateDecision {
            await decisions.next(capability: capability, subjectID: subjectID)
        }
    }

    private actor DecisionSequence {
        private var values: [PrivacyGateDecision]
        private(set) var calls: [(PrivacyCapability, PrivacySubjectID)] = []

        init(_ values: [PrivacyGateDecision]) {
            self.values = values
        }

        func next(
            capability: PrivacyCapability,
            subjectID: PrivacySubjectID
        ) -> PrivacyGateDecision {
            calls.append((capability, subjectID))
            return values.isEmpty ? .denied(.preferencesUnavailable) : values.removeFirst()
        }

        func callCount() -> Int { calls.count }
        func subjects() -> [PrivacySubjectID] { calls.map(\.1) }
    }

    private actor RestoreProbe {
        var calls = 0
        func bump() { calls += 1 }
        func count() -> Int { calls }
    }

    private final class FixtureError: Error {}

    @Test func backgroundReconciliationSchedulesOnlyAnAllowedExternalSubject() async {
        let decisions = DecisionSequence([.allowed])
        let probe = RestoreProbe()
        var scheduled = 0
        var cancelled = 0
        let controller = BackgroundSyncController(
            restoreSession: {
                await probe.bump()
                return Self.session(stableID: "google-subject-123")
            },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, _ in
                Issue.record("Scheduling reconciliation must not run a sync")
                return false
            },
            scheduleNext: { scheduled += 1 },
            cancelPending: { cancelled += 1 }
        )

        #expect(await controller.reconcilePendingRequest())

        #expect(await probe.count() == 1)
        #expect(await decisions.subjects() == [.external("google-subject-123")])
        #expect(scheduled == 1)
        #expect(cancelled == 0)
    }

    @Test func deniedOrUnavailablePreferenceCancelsWithoutSyncOrSchedule() async {
        for denial in [
            PrivacyGateDenial.receiptConsentRequired,
            .backgroundReceiptSyncDisabled,
            .preferencesUnavailable,
        ] {
            let decisions = DecisionSequence([.denied(denial)])
            var syncCalls = 0
            var scheduleCalls = 0
            var cancelCalls = 0
            let controller = BackgroundSyncController(
                restoreSession: { Self.session() },
                privacyGate: StubGate(decisions: decisions),
                runSync: { _, _ in syncCalls += 1; return true },
                scheduleNext: { scheduleCalls += 1 },
                cancelPending: { cancelCalls += 1 }
            )

            #expect(await controller.performBackgroundSync() == false)
            #expect(syncCalls == 0)
            #expect(scheduleCalls == 0)
            #expect(cancelCalls == 1)
        }
    }

    @Test func restoreFailureAndBlankIdentityFailClosed() async {
        for blankStableID in [nil, "", "   \n"] {
            let decisions = DecisionSequence([.allowed])
            var syncCalls = 0
            var cancelCalls = 0
            let controller = BackgroundSyncController(
                restoreSession: {
                    guard let blankStableID else { throw FixtureError() }
                    return Self.session(stableID: blankStableID)
                },
                privacyGate: StubGate(decisions: decisions),
                runSync: { _, _ in syncCalls += 1; return true },
                cancelPending: { cancelCalls += 1 }
            )

            #expect(await controller.performBackgroundSync() == false)
            #expect(syncCalls == 0)
            #expect(cancelCalls == 1)
            #expect(await decisions.callCount() == 0)
        }
    }

    @Test func executionPassesTheSameScopedSubjectToGateAndSync() async {
        let decisions = DecisionSequence([.allowed, .allowed])
        var receivedSubject: PrivacySubjectID?
        var scheduleCalls = 0
        let controller = BackgroundSyncController(
            restoreSession: { Self.session(stableID: "subject-A") },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, subjectID in
                receivedSubject = subjectID
                return true
            },
            scheduleNext: { scheduleCalls += 1 }
        )

        #expect(await controller.performBackgroundSync())

        #expect(receivedSubject == .external("subject-A"))
        #expect(await decisions.subjects() == [.external("subject-A"), .external("subject-A")])
        #expect(scheduleCalls == 1)
    }

    @Test func consentWithdrawalDuringSyncCancelsInsteadOfRescheduling() async {
        let decisions = DecisionSequence([.allowed, .denied(.receiptConsentRequired)])
        var syncCalls = 0
        var scheduleCalls = 0
        var cancelCalls = 0
        let controller = BackgroundSyncController(
            restoreSession: { Self.session() },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, _ in syncCalls += 1; return true },
            scheduleNext: { scheduleCalls += 1 },
            cancelPending: { cancelCalls += 1 }
        )

        #expect(await controller.performBackgroundSync() == false)

        #expect(syncCalls == 1)
        #expect(scheduleCalls == 0)
        #expect(cancelCalls == 1)
    }

    @Test func syncFailureIsReportedButStillKeepsAnAllowedChainAlive() async {
        let decisions = DecisionSequence([.allowed, .allowed])
        var scheduleCalls = 0
        let controller = BackgroundSyncController(
            restoreSession: { Self.session() },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, _ in false },
            scheduleNext: { scheduleCalls += 1 }
        )

        #expect(await controller.performBackgroundSync() == false)
        #expect(scheduleCalls == 1)
    }

    @Test func schedulingFailureCancelsAndReportsFalse() async {
        let decisions = DecisionSequence([.allowed, .allowed])
        var cancelCalls = 0
        let controller = BackgroundSyncController(
            restoreSession: { Self.session() },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, _ in true },
            scheduleNext: { throw FixtureError() },
            cancelPending: { cancelCalls += 1 }
        )

        #expect(await controller.performBackgroundSync() == false)
        #expect(cancelCalls == 1)
    }

    @Test func cancellationDuringSyncReportsFalseAndDoesNotExtendTheChain() async {
        let decisions = DecisionSequence([.allowed, .allowed])
        var scheduleCalls = 0
        let controller = BackgroundSyncController(
            restoreSession: { Self.session() },
            privacyGate: StubGate(decisions: decisions),
            runSync: { _, _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return true
            },
            scheduleNext: { scheduleCalls += 1 }
        )

        let work = Task { @MainActor in
            await controller.performBackgroundSync()
        }
        #expect(await work.value == false)
        #expect(scheduleCalls == 0)
        #expect(await decisions.callCount() == 1)
    }

    private static func session(stableID: String = "subject-123") -> BackgroundSyncSession {
        BackgroundSyncSession(
            identity: GoogleSignInIdentity(
                stableUserID: stableID,
                email: "person@example.com",
                grantedScopes: Set(GmailScope.requested)
            ),
            gmailClient: GmailReadOnlyClient(
                transport: NeverTransport(),
                auth: StaticTokenAuth(token: "unused")
            )
        )
    }

    private struct NeverTransport: GmailTransport {
        func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            Issue.record("No Gmail request expected in controller policy tests")
            throw URLError(.cancelled)
        }
    }
}
