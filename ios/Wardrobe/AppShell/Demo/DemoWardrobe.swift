import Foundation
import SwiftData

/// Fixed fictional content for App Review and product exploration. The data is
/// deliberately local-only and cannot trigger a connected feature.
enum DemoWardrobe {
    struct ItemDefinition: Equatable, Sendable {
        let id: UUID
        let name: String
        let category: String
        let subcategory: String
        let brand: String
        let colors: [String]
        let material: String
        let styleNotes: String
    }

    struct LookDefinition: Equatable, Sendable {
        let itemIDs: [UUID]
        let occasion: String
        let colorStory: String
        let rationale: String
    }

    nonisolated static let items: [ItemDefinition] = [
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000001")!,
            name: "Cloud Oxford Shirt",
            category: "top",
            subcategory: "button-down shirt",
            brand: "Fictional Atelier",
            colors: ["#E8EEF4", "white"],
            material: "cotton",
            styleNotes: "Relaxed collar and softly structured cuffs."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000002")!,
            name: "Cedar Pleated Trousers",
            category: "bottom",
            subcategory: "trousers",
            brand: "Imaginary Goods",
            colors: ["#78624D"],
            material: "wool blend",
            styleNotes: "High-rise, straight-leg tailoring."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000003")!,
            name: "Porcelain Court Sneakers",
            category: "shoe",
            subcategory: "sneakers",
            brand: "Fictional Atelier",
            colors: ["#F7F5EF"],
            material: "leather",
            styleNotes: "Minimal low-profile silhouette."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000004")!,
            name: "Moss Field Jacket",
            category: "outerwear",
            subcategory: "jacket",
            brand: "Studio Example",
            colors: ["#66705A"],
            material: "cotton twill",
            styleNotes: "Lightweight layer with four utility pockets."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000005")!,
            name: "Ink Ribbed Tee",
            category: "top",
            subcategory: "t-shirt",
            brand: "Imaginary Goods",
            colors: ["#252A34"],
            material: "organic cotton",
            styleNotes: "Close fit with a substantial ribbed neck."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000006")!,
            name: "Saffron Mini Tote",
            category: "bag",
            subcategory: "tote",
            brand: "Studio Example",
            colors: ["#C98A2E"],
            material: "vegetable-tanned leather",
            styleNotes: "Compact carryall with a detachable strap."
        ),
        ItemDefinition(
            id: UUID(uuidString: "D3A00000-0000-4000-8000-000000000007")!,
            name: "Dusk Wrap Dress",
            category: "dress",
            subcategory: "wrap dress",
            brand: "Example Studio",
            colors: ["#4C405E"],
            material: "linen blend",
            styleNotes: "Soft wrap silhouette for warm evenings."
        ),
    ]

    nonisolated static let todayLook = LookDefinition(
        itemIDs: [items[0].id, items[1].id, items[2].id, items[3].id],
        occasion: "Smart casual",
        colorStory: "Cool cloud and moss grounded by warm cedar",
        rationale: "The crisp shirt and pleated trousers feel polished, while the field jacket and court sneakers keep the look relaxed enough for an easy day out."
    )

    nonisolated static let recentLookID = UUID(
        uuidString: "D3A10000-0000-4000-8000-000000000001"
    )!

    nonisolated static let recentLook = LookDefinition(
        itemIDs: [items[4].id, items[1].id, items[2].id, items[5].id],
        occasion: "Weekend errands",
        colorStory: "Inky navy and cedar lifted by porcelain and saffron",
        rationale: "The ribbed tee and pleated trousers keep the base easy, while clean sneakers and the saffron tote add a practical, bright finish."
    )

    @MainActor
    static func seed(into modelContext: ModelContext) throws {
        guard try modelContext.fetchCount(FetchDescriptor<Item>()) == 0 else {
            throw DemoWardrobeError.nonemptyContainer
        }

        var seededItems: [UUID: Item] = [:]
        for definition in items {
            let item = Item(
                id: definition.id,
                name: definition.name,
                category: definition.category,
                subcategory: definition.subcategory,
                brand: definition.brand,
                colors: definition.colors,
                material: definition.material,
                styleNotes: definition.styleNotes,
                source: .manual,
                imageData: nil,
                thumbnailData: nil,
                featurePrint: nil
            )
            modelContext.insert(item)
            seededItems[definition.id] = item
        }

        let wornAt = Date.now.addingTimeInterval(-86_400)
        let wornItems = recentLook.itemIDs.compactMap { seededItems[$0] }
        let outfit = Outfit(
            id: recentLookID,
            createdAt: wornAt,
            occasion: recentLook.occasion,
            rationale: recentLook.rationale,
            colorStory: recentLook.colorStory,
            items: wornItems
        )
        modelContext.insert(outfit)
        for item in wornItems {
            modelContext.insert(WearLog(
                date: wornAt,
                item: item,
                outfit: outfit
            ))
        }
        try modelContext.save()
    }
}

enum DemoWardrobeError: Error, Equatable {
    case nonemptyContainer
}
