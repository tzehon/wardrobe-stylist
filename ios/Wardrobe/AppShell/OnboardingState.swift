import Foundation
import Observation

/// App-only first-run state. This intentionally does not share storage or
/// lifecycle with account-scoped privacy consent.
@MainActor
@Observable
final class OnboardingState {
    static let completionKey = "com.tth.Wardrobe.onboarding.completed.v1"

    private let defaults: UserDefaults
    private(set) var hasCompleted: Bool
    private(set) var isPresented: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let completed = defaults.bool(forKey: Self.completionKey)
        self.hasCompleted = completed
        self.isPresented = !completed
    }

    func complete() {
        defaults.set(true, forKey: Self.completionKey)
        hasCompleted = true
        isPresented = false
    }

    /// Replays education without revoking consent or changing account state.
    func replay() {
        isPresented = true
    }

    /// First-run onboarding cannot be dismissed. A replay can be closed without
    /// changing its durable completion marker.
    func dismissReplay() {
        guard hasCompleted else { return }
        isPresented = false
    }
}
