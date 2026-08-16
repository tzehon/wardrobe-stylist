import Foundation
import Observation
import SwiftData

struct LegacyAccountDataSummary: Equatable, Sendable {
    let importedItems: Int
    let outfits: Int
    let wearLogs: Int

    var isEmpty: Bool {
        importedItems == 0 && outfits == 0 && wearLogs == 0
    }
}

struct LegacyAccountDataError: Error, Equatable, LocalizedError, Sendable {
    let diagnostic: String

    var errorDescription: String? {
        "Couldn’t update older wardrobe data."
    }

    var recoverySuggestion: String? {
        "Your older imported data remains hidden and unchanged. Please try again."
    }
}

/// Resolves rows from the pre-account schema only after an explicit user
/// choice. Until then, `WardrobeAccountFilter` hides every unscoped email,
/// outfit, and wear-history row.
@MainActor
final class LegacyAccountDataResolver {
    typealias Save = @MainActor (ModelContext) throws -> Void

    private let modelContext: ModelContext
    private let save: Save

    init(
        modelContext: ModelContext,
        save: @escaping Save = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.save = save
    }

    func summary() throws -> LegacyAccountDataSummary {
        let items = try modelContext.fetch(FetchDescriptor<Item>())
        let outfits = try modelContext.fetch(FetchDescriptor<Outfit>())
        let wears = try modelContext.fetch(FetchDescriptor<WearLog>())
        return LegacyAccountDataSummary(
            importedItems: items.lazy.filter {
                $0.source == .email && $0.accountSubjectKey == nil
            }.count,
            outfits: outfits.lazy.filter { $0.accountSubjectKey == nil }.count,
            wearLogs: wears.lazy.filter { $0.accountSubjectKey == nil }.count
        )
    }

    /// Assigns all pre-account imported items and history to the account the
    /// user selected. Device-local manual/photo items remain shared and unowned.
    func keepWithAccount(subjectID: PrivacySubjectID) throws {
        let scope = WardrobeAccountScope.external(subjectID)
        try transaction {
            for item in try modelContext.fetch(FetchDescriptor<Item>())
            where item.source == .email && item.accountSubjectKey == nil {
                item.accountSubjectKey = scope.rawValue
            }
            for outfit in try modelContext.fetch(FetchDescriptor<Outfit>())
            where outfit.accountSubjectKey == nil {
                outfit.accountSubjectKey = scope.rawValue
            }
            for wear in try modelContext.fetch(FetchDescriptor<WearLog>())
            where wear.accountSubjectKey == nil {
                wear.accountSubjectKey = scope.rawValue
            }
        }
    }

    /// Deletes only ambiguous pre-account imports/history. Local manual/photo
    /// items and every already-scoped account remain untouched.
    func deleteLegacyAccountData() throws {
        try transaction {
            let wears = try modelContext.fetch(FetchDescriptor<WearLog>())
                .filter { $0.accountSubjectKey == nil }
            let outfits = try modelContext.fetch(FetchDescriptor<Outfit>())
                .filter { $0.accountSubjectKey == nil }
            let items = try modelContext.fetch(FetchDescriptor<Item>())
                .filter { $0.source == .email && $0.accountSubjectKey == nil }

            for wear in wears { modelContext.delete(wear) }
            for outfit in outfits { modelContext.delete(outfit) }
            for item in items { modelContext.delete(item) }
        }
    }

    private func transaction(_ mutation: () throws -> Void) throws {
        guard !modelContext.hasChanges else {
            throw LegacyAccountDataError(diagnostic: "Model context has pending changes")
        }
        do {
            try mutation()
            try save(modelContext)
        } catch let error as LegacyAccountDataError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw LegacyAccountDataError(diagnostic: String(describing: error))
        }
    }
}

@MainActor
@Observable
final class LegacyAccountDataResolutionController {
    enum State: Equatable {
        case loading
        case none
        case decisionRequired(LegacyAccountDataSummary)
        case failed(LegacyAccountDataError)
    }

    private(set) var state: State = .loading
    private let resolver: LegacyAccountDataResolver

    init(resolver: LegacyAccountDataResolver) {
        self.resolver = resolver
    }

    func load() {
        do {
            let summary = try resolver.summary()
            state = summary.isEmpty ? .none : .decisionRequired(summary)
        } catch {
            state = .failed(LegacyAccountDataError(diagnostic: String(describing: error)))
        }
    }

    func keepWithAccount(subjectID: PrivacySubjectID) {
        do {
            try resolver.keepWithAccount(subjectID: subjectID)
            load()
        } catch let error as LegacyAccountDataError {
            state = .failed(error)
        } catch {
            state = .failed(LegacyAccountDataError(diagnostic: String(describing: error)))
        }
    }

    func deleteLegacyAccountData() {
        do {
            try resolver.deleteLegacyAccountData()
            load()
        } catch let error as LegacyAccountDataError {
            state = .failed(error)
        } catch {
            state = .failed(LegacyAccountDataError(diagnostic: String(describing: error)))
        }
    }
}
