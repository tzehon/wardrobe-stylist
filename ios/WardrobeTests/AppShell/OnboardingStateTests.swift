import Foundation
import Testing

@testable import Wardrobe

@MainActor
struct OnboardingStateTests {
    @Test func firstLaunchRequiresOnboarding() throws {
        try withDefaults { defaults in
            let state = OnboardingState(defaults: defaults)

            #expect(!state.hasCompleted)
            #expect(state.isPresented)
        }
    }

    @Test func completionPersistsAcrossAppStateRecreation() throws {
        try withDefaults { defaults in
            let state = OnboardingState(defaults: defaults)

            state.complete()

            #expect(state.hasCompleted)
            #expect(!state.isPresented)
            let restored = OnboardingState(defaults: defaults)
            #expect(restored.hasCompleted)
            #expect(!restored.isPresented)
        }
    }

    @Test func replayCanCloseWithoutClearingCompletion() throws {
        try withDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            state.complete()

            state.replay()
            #expect(state.isPresented)
            #expect(state.hasCompleted)

            state.dismissReplay()
            #expect(!state.isPresented)
            #expect(state.hasCompleted)
            #expect(defaults.bool(forKey: OnboardingState.completionKey))
        }
    }

    @Test func firstRunCannotBeDismissedWithoutCompletion() throws {
        try withDefaults { defaults in
            let state = OnboardingState(defaults: defaults)

            state.dismissReplay()

            #expect(state.isPresented)
            #expect(!state.hasCompleted)
        }
    }

    private func withDefaults(
        _ test: (UserDefaults) throws -> Void
    ) throws {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try test(defaults)
    }
}
