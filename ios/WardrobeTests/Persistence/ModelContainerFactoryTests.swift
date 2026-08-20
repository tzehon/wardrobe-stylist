import SwiftData
import Testing

@testable import Wardrobe

@MainActor
struct ModelContainerFactoryTests {
    @Test func schemaContainsOnlyDeviceLocalModels() throws {
        let names = Set(ModelContainerFactory.schema.entities.map(\.name))
        #expect(names == Set(["Item", "Outfit", "WearLog"]))
        #expect(WardrobeSchema.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test func inMemoryContainerPersistsManualWardrobeAndHistory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        let item = Item(name: "Navy shirt", category: "top", source: .manual)
        let outfit = Outfit(items: [item])
        let wear = WearLog(item: item, outfit: outfit)
        context.insert(item)
        context.insert(outfit)
        context.insert(wear)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WearLog>()) == 1)
    }
}
