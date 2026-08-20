import Observation
import SwiftData

/// The single construction point for Wardrobe's SwiftData container.
///
/// Production and tests both use the fresh device-local schema; tests may
/// supply an in-memory or temporary on-disk configuration.
enum ModelContainerFactory {
    static let schema = Schema(versionedSchema: WardrobeSchema.self)

    static func make(
        configurations: [ModelConfiguration] = []
    ) throws -> ModelContainer {
        if configurations.isEmpty {
            return try ModelContainer(for: schema)
        }
        return try ModelContainer(
            for: schema,
            configurations: configurations
        )
    }

    static func makeInMemory() throws -> ModelContainer {
        try make(configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true),
        ])
    }
}

/// User-safe information for a store-open failure. The underlying diagnostic is
/// retained for logs/tests, but is never rendered as user-facing UI.
struct PersistentStoreFailure: Equatable, Sendable {
    let diagnostic: String

    static let userMessage = "Your wardrobe couldn’t be opened. Your data has not been deleted."
}

/// Owns launch-time container creation and allows a non-destructive retry when
/// opening the persistent store fails.
@MainActor
@Observable
final class PersistentStoreController {
    enum State {
        case loading
        case ready(ModelContainer)
        case failed(PersistentStoreFailure)
    }

    private(set) var state: State = .loading
    private(set) var hasStartedLoading = false

    var container: ModelContainer? {
        guard case .ready(let container) = state else { return nil }
        return container
    }

    private let loader: @MainActor () throws -> ModelContainer

    init(
        automaticallyLoad: Bool = true,
        loader: @escaping @MainActor () throws -> ModelContainer = {
            try ModelContainerFactory.make()
        }
    ) {
        self.loader = loader
        if automaticallyLoad {
            load()
        }
    }

    /// Starts a deliberately deferred production-store open exactly once.
    /// Reviewer Demo launch uses this so the isolated in-memory tour neither
    /// reads nor migrates the real wardrobe before the reviewer exits it.
    func loadIfNeeded() {
        guard !hasStartedLoading else { return }
        load()
    }

    /// Explicitly transitions from an isolated reviewer Demo to the user's
    /// production wardrobe. A normal `loadIfNeeded` remains one-shot so SwiftUI
    /// view updates cannot accidentally retry a failed migration in a loop.
    func beginProductionStoreAfterReviewerDemo() {
        load()
    }

    func retry() {
        load()
    }

    private func load() {
        hasStartedLoading = true
        state = .loading
        do {
            state = .ready(try loader())
        } catch {
            state = .failed(PersistentStoreFailure(diagnostic: String(describing: error)))
        }
    }
}
