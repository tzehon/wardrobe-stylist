import Foundation
import SwiftData

struct SampleWardrobeError: Error, LocalizedError, Sendable {
    let diagnostic: String

    var errorDescription: String? { "Couldn’t Update Samples" }
    var recoverySuggestion: String? {
        "Your existing wardrobe was not changed. Please try again."
    }
}

/// Optional local sample data for exploring the app before adding personal
/// items. Fixed IDs make seeding idempotent and let removal target only these
/// rows; user-created items keep their independently generated IDs.
@MainActor
struct SampleWardrobeSeeder {
    struct Sample: Equatable, Sendable {
        let id: UUID
        let name: String
        let category: String
        let brand: String
        let colors: [String]
        let material: String
    }

    static let samples = [
        Sample(
            id: UUID(uuidString: "5A4D504C-4501-4000-8000-000000000001")!,
            name: "Navy Oxford Shirt",
            category: "top",
            brand: "Sample Wardrobe",
            colors: ["navy"],
            material: "cotton"
        ),
        Sample(
            id: UUID(uuidString: "5A4D504C-4501-4000-8000-000000000002")!,
            name: "Stone Chinos",
            category: "bottom",
            brand: "Sample Wardrobe",
            colors: ["stone"],
            material: "cotton"
        ),
        Sample(
            id: UUID(uuidString: "5A4D504C-4501-4000-8000-000000000003")!,
            name: "White Leather Sneakers",
            category: "shoe",
            brand: "Sample Wardrobe",
            colors: ["white"],
            material: "leather"
        ),
        Sample(
            id: UUID(uuidString: "5A4D504C-4501-4000-8000-000000000004")!,
            name: "Olive Overshirt",
            category: "outerwear",
            brand: "Sample Wardrobe",
            colors: ["olive"],
            material: "cotton twill"
        ),
    ]

    static let sampleIDs = Set(samples.map(\.id))

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func seed() throws -> Int {
        try requireCleanContext()

        let existing: [Item]
        do {
            existing = try modelContext.fetch(FetchDescriptor<Item>())
        } catch {
            throw safeError(error)
        }
        let existingIDs = Set(existing.map(\.id))
        let missing = Self.samples.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return 0 }

        do {
            for sample in missing {
                modelContext.insert(Item(
                    id: sample.id,
                    name: sample.name,
                    category: sample.category,
                    brand: sample.brand,
                    colors: sample.colors,
                    material: sample.material,
                    source: .manual
                ))
            }
            try modelContext.save()
            return missing.count
        } catch {
            modelContext.rollback()
            throw safeError(error)
        }
    }

    @discardableResult
    func remove() throws -> Int {
        try requireCleanContext()

        let samples: [Item]
        do {
            samples = try modelContext.fetch(FetchDescriptor<Item>())
                .filter { Self.sampleIDs.contains($0.id) }
        } catch {
            throw safeError(error)
        }
        guard !samples.isEmpty else { return 0 }

        do {
            for item in samples { modelContext.delete(item) }
            try modelContext.save()
            return samples.count
        } catch {
            modelContext.rollback()
            throw safeError(error)
        }
    }

    private func requireCleanContext() throws {
        guard !modelContext.hasChanges else {
            throw safeError(SampleSeederInternalError.pendingChanges)
        }
    }

    private func safeError(_ error: Error) -> SampleWardrobeError {
        SampleWardrobeError(diagnostic: String(describing: error))
    }

    private enum SampleSeederInternalError: Error {
        case pendingChanges
    }
}
