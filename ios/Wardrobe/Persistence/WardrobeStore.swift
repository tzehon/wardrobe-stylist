import Foundation
import Observation
import SwiftData

/// A persistence failure with copy that is safe to show to the user.
///
/// The diagnostic is retained for tests and future logging, but views must use
/// only `title` and `message`; raw store errors may contain implementation
/// details that do not help someone recover.
struct WardrobePersistenceError: Error, Equatable, LocalizedError, Sendable {
    enum Operation: Equatable, Sendable {
        case addItem
        case updateItem
        case deleteItem
        case recordWear
        case rateOutfit
    }

    let operation: Operation
    let diagnostic: String

    init(operation: Operation, underlying: Error) {
        self.operation = operation
        self.diagnostic = String(describing: underlying)
    }

    var title: String {
        switch operation {
        case .addItem: "Couldn’t Save Item"
        case .updateItem: "Couldn’t Update Item"
        case .deleteItem: "Couldn’t Delete Item"
        case .recordWear: "Couldn’t Record Outfit"
        case .rateOutfit: "Couldn’t Save Rating"
        }
    }

    var message: String {
        switch operation {
        case .addItem:
            "Your item wasn’t added. Your details are still here, so you can try again."
        case .updateItem:
            "Your changes weren’t saved. Your item is unchanged, so you can try again."
        case .deleteItem:
            "The item is still in your catalog. Please try again."
        case .recordWear:
            "This look wasn’t marked as worn. Please try again."
        case .rateOutfit:
            "Your rating wasn’t saved. The previous rating is unchanged, so you can try again."
        }
    }

    var errorDescription: String? { title }
    var recoverySuggestion: String? { message }
}

private enum WardrobeStoreError: Error {
    case pendingChanges
    case itemFromDifferentStore
    case itemAlreadyDeleted
    case emptyWearSelection
    case itemOutsideAccountScope
    case outfitFromDifferentStore
    case outfitAlreadyDeleted
    case outfitOutsideAccountScope
    case invalidOutfitFeedback
    case outfitHasNoWearLogs
    case invalidItemInput
    case itemNotStyleable
}

/// Value input for Add Item's manual-photo write. The store creates the
/// SwiftData model inside the transaction so retrying after rollback never
/// reuses a detached model.
struct ManualItemInput: Sendable {
    let name: String
    let category: String
    let subcategory: String?
    let brand: String?
    let colors: [String]
    let material: String?
    let styleNotes: String?
    let size: String?
    let purchaseDate: Date?
    let purchasePrice: Double?
    let purchaseCurrency: String?
    let source: ItemSource
    let imageData: Data?
    let thumbnailData: Data?
}

/// Value input for correcting an existing catalog item.
struct ItemUpdateInput: Equatable, Sendable {
    let name: String
    let category: String
    let subcategory: String?
    let brand: String?
    let colors: [String]
    let material: String?
    let styleNotes: String?
    let size: String?
    let purchaseDate: Date?
    let purchasePrice: Double?
    let purchaseCurrency: String?
    let imageUpdate: ItemImageUpdate
}

enum ItemImageUpdate: Equatable, Sendable {
    case unchanged
    case replace(imageData: Data, thumbnailData: Data)
    case remove
}

/// The user-triggered wardrobe mutations exposed to UI and feature code.
/// Keeping this protocol small makes save failures deterministic in tests.
@MainActor
protocol WardrobeStoring {
    @discardableResult
    func addItem(_ input: ManualItemInput) throws -> Item
    func updateItem(_ item: Item, with input: ItemUpdateInput) throws
    func deleteItem(_ item: Item) throws
    func setFavorite(_ isFavorite: Bool, for item: Item) throws
    func setArchived(_ isArchived: Bool, for item: Item) throws

    @discardableResult
    func recordWear(
        items: [Item],
        occasion: String?,
        rationale: String?,
        colorStory: String?,
        date: Date
    ) throws -> Outfit

    func rateOutfit(_ outfit: Outfit, feedback: Int) throws
}

/// The canonical transaction boundary for user-triggered SwiftData writes.
/// A mutation is successful only after `ModelContext.save()` returns. Any
/// mutation or save failure rolls the pending transaction back before a safe
/// `WardrobePersistenceError` reaches the UI.
@MainActor
final class WardrobeStore: WardrobeStoring {
    typealias Save = @MainActor (ModelContext) throws -> Void

    private let modelContext: ModelContext
    private let accountScope: WardrobeAccountScope
    private let save: Save

    init(
        modelContext: ModelContext,
        accountScope: WardrobeAccountScope = .deviceLocal,
        save: @escaping Save = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.accountScope = accountScope
        self.save = save
    }

    @discardableResult
    func addItem(_ input: ManualItemInput) throws -> Item {
        try validateItemFields(
            name: input.name,
            category: input.category,
            brand: input.brand,
            colors: input.colors,
            material: input.material,
            purchasePrice: input.purchasePrice,
            purchaseCurrency: input.purchaseCurrency,
            operation: .addItem
        )
        return try transaction(operation: .addItem) {
            let item = Item(
                name: input.name,
                category: input.category,
                subcategory: input.subcategory,
                brand: input.brand,
                colors: input.colors,
                size: input.size,
                material: input.material,
                styleNotes: input.styleNotes,
                source: input.source,
                purchaseDate: input.purchaseDate,
                purchasePrice: input.purchasePrice,
                purchaseCurrency: input.purchaseCurrency,
                imageData: input.imageData,
                thumbnailData: input.thumbnailData
            )
            modelContext.insert(item)
            return item
        }
    }

    func deleteItem(_ item: Item) throws {
        try validate(item, operation: .deleteItem, requireAccountVisibility: true)
        try transaction(operation: .deleteItem) {
            let dependents = try modelContext.fetch(FetchDescriptor<Item>())
                .filter { $0.possibleDuplicateOfItemID == item.id }
            if let promoted = dependents.first {
                promoted.possibleDuplicateOfItemID = nil
                for dependent in dependents.dropFirst() {
                    dependent.possibleDuplicateOfItemID = promoted.id
                }
            }
            modelContext.delete(item)
        }
    }

    func updateItem(_ item: Item, with input: ItemUpdateInput) throws {
        try validate(item, operation: .updateItem, requireAccountVisibility: true)
        try validateItemFields(
            name: input.name,
            category: input.category,
            brand: input.brand,
            colors: input.colors,
            material: input.material,
            purchasePrice: input.purchasePrice,
            purchaseCurrency: input.purchaseCurrency,
            operation: .updateItem
        )
        try transaction(operation: .updateItem) {
            item.name = input.name
            item.category = input.category
            item.subcategory = input.subcategory
            item.brand = input.brand
            item.colors = input.colors
            item.material = input.material
            item.styleNotes = input.styleNotes
            item.size = input.size
            item.purchaseDate = input.purchaseDate
            item.purchasePrice = input.purchasePrice
            item.purchaseCurrency = input.purchaseCurrency
            switch input.imageUpdate {
            case .unchanged:
                break
            case .replace(let imageData, let thumbnailData):
                item.imageData = imageData
                item.thumbnailData = thumbnailData
                item.featurePrint = nil
            case .remove:
                item.imageData = nil
                item.thumbnailData = nil
                item.featurePrint = nil
            }
        }
    }

    func setFavorite(_ isFavorite: Bool, for item: Item) throws {
        try mutateItem(item) { $0.isFavorite = isFavorite }
    }

    func setArchived(_ isArchived: Bool, for item: Item) throws {
        try mutateItem(item) { $0.isArchived = isArchived }
    }

    private func mutateItem(_ item: Item, mutation: (Item) -> Void) throws {
        try validate(item, operation: .updateItem, requireAccountVisibility: true)
        try transaction(operation: .updateItem) { mutation(item) }
    }

    @discardableResult
    func recordWear(
        items: [Item],
        occasion: String?,
        rationale: String?,
        colorStory: String?,
        date: Date
    ) throws -> Outfit {
        guard !items.isEmpty else {
            throw WardrobePersistenceError(
                operation: .recordWear,
                underlying: WardrobeStoreError.emptyWearSelection
            )
        }
        let uniqueItems = items.reduce(into: [Item]()) { result, item in
            if !result.contains(where: { $0.id == item.id }) {
                result.append(item)
            }
        }
        for item in uniqueItems {
            try validate(item, operation: .recordWear)
            guard WardrobeAccountFilter.isVisible(item, in: accountScope) else {
                throw WardrobePersistenceError(
                    operation: .recordWear,
                    underlying: WardrobeStoreError.itemOutsideAccountScope
                )
            }
            guard !item.isArchived else {
                throw WardrobePersistenceError(
                    operation: .recordWear,
                    underlying: WardrobeStoreError.itemNotStyleable
                )
            }
        }
        return try transaction(operation: .recordWear) {
            let outfit = Outfit(
                createdAt: date,
                occasion: occasion,
                rationale: rationale,
                colorStory: colorStory,
                items: uniqueItems
            )
            modelContext.insert(outfit)
            for item in uniqueItems {
                modelContext.insert(WearLog(
                    date: date,
                    item: item,
                    outfit: outfit
                ))
            }
            return outfit
        }
    }

    func rateOutfit(_ outfit: Outfit, feedback: Int) throws {
        guard (1...5).contains(feedback) else {
            throw WardrobePersistenceError(
                operation: .rateOutfit,
                underlying: WardrobeStoreError.invalidOutfitFeedback
            )
        }
        try validate(outfit, operation: .rateOutfit)
        try transaction(operation: .rateOutfit) {
            let logs = try modelContext.fetch(FetchDescriptor<WearLog>())
                .filter {
                    $0.outfit?.id == outfit.id
                        && WardrobeAccountFilter.isVisible($0, in: accountScope)
                }
            guard !logs.isEmpty else { throw WardrobeStoreError.outfitHasNoWearLogs }
            for log in logs { log.feedback = feedback }
        }
    }

    private func transaction<Result>(
        operation: WardrobePersistenceError.Operation,
        mutation: () throws -> Result
    ) throws -> Result {
        // Rollback is context-wide. Refuse to begin while an older unrelated
        // change is pending, rather than silently committing or discarding it
        // under this action's success/error semantics.
        if modelContext.hasChanges {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.pendingChanges
            )
        }

        do {
            let result = try mutation()
            try save(modelContext)
            return result
        } catch {
            modelContext.rollback()
            throw WardrobePersistenceError(operation: operation, underlying: error)
        }
    }

    private func validate(
        _ item: Item,
        operation: WardrobePersistenceError.Operation,
        requireAccountVisibility: Bool = false
    ) throws {
        guard item.modelContext === modelContext else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.itemFromDifferentStore
            )
        }
        guard !item.isDeleted else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.itemAlreadyDeleted
            )
        }
        if requireAccountVisibility,
           !WardrobeAccountFilter.isVisible(item, in: accountScope) {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.itemOutsideAccountScope
            )
        }
    }

    private func validateItemFields(
        name: String,
        category: String,
        brand: String?,
        colors: [String],
        material: String?,
        purchasePrice: Double?,
        purchaseCurrency: String?,
        operation: WardrobePersistenceError.Operation
    ) throws {
        let validPrice = purchasePrice.map { $0.isFinite && $0 >= 0 } ?? true
        let validCurrency = purchaseCurrency.map { value in
            value.count == 3 && value.unicodeScalars.allSatisfy {
                $0.isASCII && CharacterSet.uppercaseLetters.contains($0)
            }
        } ?? true
        let validBrand = brand.map { value in
            RecommendContractLimits.isWithin(
                value,
                maximum: RecommendContractLimits.maximumBrandLength
            )
        } ?? true
        let validMaterial = material.map { value in
            RecommendContractLimits.isWithin(
                value,
                maximum: RecommendContractLimits.maximumMaterialLength
            )
        } ?? true
        guard !name.trimmedRequired.isEmpty,
              !category.trimmedRequired.isEmpty,
              RecommendContractLimits.isWithin(
                  name,
                  maximum: RecommendContractLimits.maximumNameLength
              ),
              RecommendContractLimits.isWithin(
                  category,
                  maximum: RecommendContractLimits.maximumCategoryLength
              ),
              validBrand,
              colors.count <= RecommendContractLimits.maximumColors,
              validMaterial,
              validPrice,
              validCurrency else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.invalidItemInput
            )
        }
    }

    private func validate(
        _ outfit: Outfit,
        operation: WardrobePersistenceError.Operation
    ) throws {
        guard outfit.modelContext === modelContext else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.outfitFromDifferentStore
            )
        }
        guard !outfit.isDeleted else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.outfitAlreadyDeleted
            )
        }
        guard WardrobeAccountFilter.isVisible(outfit, in: accountScope) else {
            throw WardrobePersistenceError(
                operation: operation,
                underlying: WardrobeStoreError.outfitOutsideAccountScope
            )
        }
    }
}

/// Shared UI write state. `onSuccess` runs strictly after the write (including
/// its save) succeeds, so views cannot dismiss or show a success checkmark for
/// a transaction that was rolled back.
@MainActor
@Observable
final class WardrobeWriteCoordinator {
    private(set) var error: WardrobePersistenceError?

    func perform(
        operation: WardrobePersistenceError.Operation,
        write: () throws -> Void,
        onSuccess: () -> Void = {}
    ) {
        do {
            try write()
            error = nil
            onSuccess()
        } catch let persistenceError as WardrobePersistenceError {
            error = persistenceError
        } catch let underlyingError {
            error = WardrobePersistenceError(operation: operation, underlying: underlyingError)
        }
    }

    func clearError() {
        error = nil
    }
}
