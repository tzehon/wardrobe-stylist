import Foundation
import SwiftData
import Testing
import UIKit

@testable import Wardrobe

@MainActor
struct WardrobeStoreDiskPersistenceTests {
    @Test func photoAndEditedNameSurviveSeparateStoreReopens() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wardrobe-photo-persistence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("wardrobe.store")

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 640, height: 480), format: format
        ).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
        let photo = try #require(image.jpegData(compressionQuality: 0.8))
        let thumbnail = try #require(ImageProcessor.thumbnailData(from: image))

        // Each scope releases its context/container before the next opens the
        // same temporary disk store. No production store or private photo is used.
        let itemID = try withStore(at: storeURL) { context in
            var draft = ItemDraft()
            draft.name = "Blue test shirt"
            let item = try WardrobeStore(modelContext: context).addItem(
                draft.manualInput(source: .photo, imageData: photo, thumbnailData: thumbnail)
            )
            #expect(!context.hasChanges)
            return item.id
        }
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        try withStore(at: storeURL) { context in
            let items = try context.fetch(FetchDescriptor<Item>())
            #expect(items.count == 1)
            let item = try #require(items.first)
            #expect(item.id == itemID)
            #expect(item.name == "Blue test shirt")
            #expect(item.imageData == photo)
            #expect(item.thumbnailData == thumbnail)

            var edit = ItemEditDraft(item: item)
            edit.name = "Edited blue shirt"
            try WardrobeStore(modelContext: context).updateItem(item, with: edit.updateInput)
            #expect(!context.hasChanges)
        }

        try withStore(at: storeURL) { context in
            let items = try context.fetch(FetchDescriptor<Item>())
            #expect(items.count == 1)
            let item = try #require(items.first)
            #expect(item.id == itemID)
            #expect(item.name == "Edited blue shirt")
            #expect(item.source == .photo)
            #expect(item.imageData == photo)
            #expect(item.thumbnailData == thumbnail)
            #expect(item.imageData.flatMap(UIImage.init(data:)) != nil)
            #expect(item.thumbnailData.flatMap(UIImage.init(data:)) != nil)
        }
    }

    private func withStore<Result>(
        at url: URL,
        _ body: (ModelContext) throws -> Result
    ) throws -> Result {
        try autoreleasepool {
            let container = try ModelContainerFactory.make(configurations: [
                ModelConfiguration(schema: ModelContainerFactory.schema, url: url,
                                   cloudKitDatabase: .none),
            ])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return try body(context)
        }
    }
}
