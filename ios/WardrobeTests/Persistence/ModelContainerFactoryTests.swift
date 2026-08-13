import Foundation
import SwiftData
import Testing

@testable import Wardrobe

// These file-private, top-level model types reproduce the declarations that
// shipped before the production models moved into `WardrobeSchemaV1`. Keeping
// the historical shape independent of the production aliases makes the
// compatibility test sensitive to persistent entity-name or checksum changes.
@Model
private final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var subcategory: String?
    var brand: String?
    var colors: [String]
    var material: String?
    var styleNotes: String?
    var source: Wardrobe.ItemSource
    var purchaseDate: Date?
    var sourceMsgId: String?
    var imageURL: String?

    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var featurePrint: Data?

    @Relationship(deleteRule: .nullify, inverse: \WearLog.item) var wears: [WearLog]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        subcategory: String? = nil,
        brand: String? = nil,
        colors: [String] = [],
        material: String? = nil,
        styleNotes: String? = nil,
        source: Wardrobe.ItemSource = .manual,
        purchaseDate: Date? = nil,
        sourceMsgId: String? = nil,
        imageURL: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        featurePrint: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.colors = colors
        self.material = material
        self.styleNotes = styleNotes
        self.source = source
        self.purchaseDate = purchaseDate
        self.sourceMsgId = sourceMsgId
        self.imageURL = imageURL
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.featurePrint = featurePrint
        self.wears = []
    }
}

@Model
private final class Outfit {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var occasion: String?
    var rationale: String?
    var colorStory: String?

    @Relationship var items: [Item]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        occasion: String? = nil,
        rationale: String? = nil,
        colorStory: String? = nil,
        items: [Item] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.occasion = occasion
        self.rationale = rationale
        self.colorStory = colorStory
        self.items = items
    }
}

@Model
private final class WearLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var item: Item?
    var outfit: Outfit?
    var feedback: Int?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        item: Item? = nil,
        outfit: Outfit? = nil,
        feedback: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.outfit = outfit
        self.feedback = feedback
    }
}

@MainActor
struct ModelContainerFactoryTests {
    private let itemID = UUID(uuidString: "C5B8CA21-B244-4D23-BF7E-68336B3D075E")!
    private let outfitID = UUID(uuidString: "35DE43F8-185E-47D2-9998-B5EBA41119DE")!
    private let wearLogID = UUID(uuidString: "404F52EF-B184-444B-83D5-E87877A40B61")!

    @Test func versionOneSchemaPreservesTheShippedPersistentMetadata() {
        let legacySchema = Schema([Item.self, Outfit.self, WearLog.self])
        let versionOneSchema = Schema(versionedSchema: WardrobeSchemaV1.self)

        #expect(legacySchema.version == Schema.Version(1, 0, 0))
        #expect(WardrobeSchemaV1.versionIdentifier == legacySchema.version)
        #expect(persistentMetadata(in: versionOneSchema) == persistentMetadata(in: legacySchema))
        #expect(WardrobeSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(Set(ModelContainerFactory.schema.entities.map(\.name)) == [
            "GmailSyncState",
            "Item",
            "Outfit",
            "ProcessedGmailMessage",
            "WearLog",
        ])
    }

    @Test func factoryPersistsAllModelsAndRelationshipsInMemory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let item = Wardrobe.Item(name: "Navy linen shirt", category: "top", source: .manual)
        let outfit = Wardrobe.Outfit(occasion: "Work", items: [item])
        let wearLog = Wardrobe.WearLog(item: item, outfit: outfit, feedback: 5)
        context.insert(item)
        context.insert(outfit)
        context.insert(wearLog)
        try context.save()

        let fetchedItems = try context.fetch(FetchDescriptor<Wardrobe.Item>())
        let fetchedOutfits = try context.fetch(FetchDescriptor<Wardrobe.Outfit>())
        let fetchedWearLogs = try context.fetch(FetchDescriptor<Wardrobe.WearLog>())
        #expect(fetchedItems.count == 1)
        #expect(fetchedOutfits.first?.items.map(\.id) == [item.id])
        #expect(fetchedWearLogs.first?.item?.id == item.id)
        #expect(fetchedWearLogs.first?.outfit?.id == outfit.id)
    }

    @Test func factoryOpensAStoreWrittenByTheShippedUnversionedSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WardrobeMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("Wardrobe.store")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try writeLegacyStore(to: storeURL)

        let configuration = ModelConfiguration(
            "MigrationFixture",
            schema: ModelContainerFactory.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainerFactory.make(configurations: [configuration])
        let context = container.mainContext

        let item = try #require(context.fetch(FetchDescriptor<Wardrobe.Item>()).first)
        let outfit = try #require(context.fetch(FetchDescriptor<Wardrobe.Outfit>()).first)
        let wearLog = try #require(context.fetch(FetchDescriptor<Wardrobe.WearLog>()).first)
        #expect(item.id == itemID)
        #expect(item.name == "Legacy navy shirt")
        #expect(item.category == "top")
        #expect(item.subcategory == "button-down")
        #expect(item.brand == "Archive")
        #expect(item.colors == ["navy", "white"])
        #expect(item.material == "linen")
        #expect(item.styleNotes == "relaxed")
        #expect(item.source == .email)
        #expect(item.sourceMsgId == "legacy-message")
        #expect(item.imageURL == "https://example.com/shirt.jpg")
        #expect(item.imageData == Data([0x01, 0x02]))
        #expect(item.thumbnailData == Data([0x03]))
        #expect(item.featurePrint == Data([0x04, 0x05]))
        #expect(item.accountSubjectKey == nil)
        #expect(!WardrobeAccountFilter.isVisible(item, in: .deviceLocal))
        #expect(outfit.id == outfitID)
        #expect(outfit.items.map(\.id) == [itemID])
        #expect(outfit.accountSubjectKey == nil)
        #expect(!WardrobeAccountFilter.isVisible(outfit, in: .deviceLocal))
        #expect(wearLog.id == wearLogID)
        #expect(wearLog.item?.id == itemID)
        #expect(wearLog.outfit?.id == outfitID)
        #expect(wearLog.feedback == 4)
        #expect(wearLog.accountSubjectKey == nil)
        #expect(!WardrobeAccountFilter.isVisible(wearLog, in: .deviceLocal))
        #expect(try context.fetch(FetchDescriptor<Wardrobe.ProcessedGmailMessage>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Wardrobe.GmailSyncState>()).isEmpty)
    }

    @Test func storeControllerSurfacesFailureAndCanRetryWithoutDeletingData() throws {
        struct FixtureError: Error {}

        let expectedContainer = try ModelContainerFactory.makeInMemory()
        var attempts = 0
        let controller = PersistentStoreController {
            attempts += 1
            if attempts == 1 {
                throw FixtureError()
            }
            return expectedContainer
        }

        guard case .failed(let failure) = controller.state else {
            Issue.record("Expected the initial store load to fail")
            return
        }
        #expect(attempts == 1)
        #expect(failure.diagnostic.contains("FixtureError"))
        #expect(!PersistentStoreFailure.userMessage.contains(failure.diagnostic))

        controller.retry()

        #expect(attempts == 2)
        #expect(controller.container === expectedContainer)
    }

    private func writeLegacyStore(to storeURL: URL) throws {
        let legacySchema = Schema([Item.self, Outfit.self, WearLog.self])
        let configuration = ModelConfiguration(
            "MigrationFixture",
            schema: legacySchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: legacySchema, configurations: [configuration])
        let context = container.mainContext
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let item = Item(
            id: itemID,
            name: "Legacy navy shirt",
            category: "top",
            subcategory: "button-down",
            brand: "Archive",
            colors: ["navy", "white"],
            material: "linen",
            styleNotes: "relaxed",
            source: .email,
            purchaseDate: purchaseDate,
            sourceMsgId: "legacy-message",
            imageURL: "https://example.com/shirt.jpg",
            imageData: Data([0x01, 0x02]),
            thumbnailData: Data([0x03]),
            featurePrint: Data([0x04, 0x05])
        )
        let outfit = Outfit(
            id: outfitID,
            createdAt: purchaseDate,
            occasion: "Work",
            rationale: "Layered",
            colorStory: "Navy and white",
            items: [item]
        )
        let wearLog = WearLog(
            id: wearLogID,
            date: purchaseDate,
            item: item,
            outfit: outfit,
            feedback: 4
        )
        context.insert(item)
        context.insert(outfit)
        context.insert(wearLog)
        try context.save()
    }

    /// Compares the store-relevant schema description while deliberately
    /// excluding runtime model and key-path object identity. SwiftData's
    /// `Schema ==` includes those identities, so independently declared model
    /// fixtures compare unequal even when they produce the same store shape.
    private func persistentMetadata(in schema: Schema) -> [String] {
        schema.entities
            .sorted { $0.name < $1.name }
            .flatMap { entity in
                let properties = entity.properties
                    .sorted { $0.name < $1.name }
                    .map { property -> String in
                        if let attribute = property as? Schema.Attribute {
                            return [
                                "attribute",
                                attribute.name,
                                attribute.originalName,
                                String(describing: attribute.valueType),
                                String(attribute.isOptional),
                                String(attribute.isUnique),
                                String(attribute.isTransformable),
                                attribute.debugDescription,
                            ].joined(separator: "|")
                        }
                        if let relationship = property as? Schema.Relationship {
                            return [
                                "relationship",
                                relationship.name,
                                relationship.originalName,
                                String(describing: relationship.valueType),
                                relationship.destination,
                                relationship.deleteRule.rawValue,
                                relationship.inverseName ?? "",
                                String(describing: relationship.minimumModelCount),
                                String(describing: relationship.maximumModelCount),
                                String(relationship.isUnique),
                            ].joined(separator: "|")
                        }
                        return "unknown|\(property.name)|\(String(describing: property.valueType))"
                    }
                let uniqueness = entity.uniquenessConstraints
                    .map { $0.sorted().joined(separator: ",") }
                    .sorted()
                    .joined(separator: ";")
                return ["entity|\(entity.name)|unique|\(uniqueness)"] + properties
            }
    }
}
