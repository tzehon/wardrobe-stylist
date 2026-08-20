import Observation
import SwiftData

/// Owns the lifetime of the fictional reviewer experience.
///
/// The demo container exists only while `isActive` is true. It is never the
/// app's production container, is never stored on disk, and is discarded in
/// full on exit. All demo views receive this controller instead of constructing
/// backend or notification dependencies.
@MainActor
@Observable
final class DemoModeController {
    enum State {
        case inactive
        case active(DemoSession)
        case failed(DemoModeFailure)
    }

    private(set) var state: State = .inactive

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    var session: DemoSession? {
        guard case .active(let session) = state else { return nil }
        return session
    }

    var failure: DemoModeFailure? {
        guard case .failed(let failure) = state else { return nil }
        return failure
    }

    private let makeContainer: @MainActor () throws -> ModelContainer
    private let seed: @MainActor (ModelContext) throws -> Void

    init(
        automaticallyEnter: Bool = false,
        makeContainer: @escaping @MainActor () throws -> ModelContainer = {
            try ModelContainerFactory.makeInMemory()
        },
        seed: @escaping @MainActor (ModelContext) throws -> Void = { context in
            try DemoWardrobe.seed(into: context)
        }
    ) {
        self.makeContainer = makeContainer
        self.seed = seed
        if automaticallyEnter {
            _ = enter()
        }
    }

    @discardableResult
    func enter() -> Bool {
        if isActive { return true }

        do {
            let container = try makeContainer()
            let context = ModelContext(container)
            try seed(context)
            state = .active(DemoSession(container: container))
            return true
        } catch {
            state = .failed(DemoModeFailure(diagnostic: String(describing: error)))
            return false
        }
    }

    func exit() {
        // Releasing the sole strong reference drops the in-memory store and
        // every edit made during this demo session.
        state = .inactive
    }

    /// Replaces the entire disposable store instead of deleting individual
    /// rows. This is the demo's destructive data control and can never reach
    /// the production container because that container is not retained here.
    @discardableResult
    func reset() -> Bool {
        state = .inactive
        return enter()
    }

    func clearFailure() {
        guard case .failed = state else { return }
        state = .inactive
    }
}

enum DemoLaunchPolicy {
    static let argument = "--wardrobe-demo"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(argument)
    }
}

enum DemoConnectedCapability: String, CaseIterable, Sendable {
    case backendStyling
    case notifications
}

enum DemoConnectedFeaturePolicy {
    static func isEnabled(_: DemoConnectedCapability) -> Bool {
        false
    }
}

@MainActor
final class DemoSession {
    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }
}

struct DemoModeFailure: Error, Equatable, Sendable {
    let diagnostic: String

    static let userMessage = "The demo couldn’t be opened. Your wardrobe was not changed."
}
