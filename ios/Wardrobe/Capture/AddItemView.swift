import SwiftData
import SwiftUI

/// Add a local item with optional photo capture. Items without a photo are
/// stored as manual entries and receive a category illustration in the catalog.
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ItemDraft()
    @State private var image: UIImage?
    @State private var removesExistingImage = false
    @State private var imageProcessingFailed = false
    @State private var writes = WardrobeWriteCoordinator()

    private static let categories = CatalogOrganizer.canonicalOrder

    var body: some View {
        NavigationStack {
            Form {
                ItemPhotoEditor(
                    selectedImage: $image,
                    removesExistingImage: $removesExistingImage,
                    existingItem: nil
                )
                ItemDetailsForm(draft: $draft, categories: Self.categories)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier("item.add.save")
                }
            }
            .alert("Couldn’t Prepare Image", isPresented: $imageProcessingFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a different image and try again. Your item details are still here.")
            }
            .wardrobePersistenceAlert(writes)
        }
    }

    private func save() {
        guard draft.canSave else { return }
        let imageData: Data?
        let thumbnailData: Data?
        if let image {
            guard let full = ImageProcessor.imageData(from: image),
                  let thumbnail = ImageProcessor.thumbnailData(from: image) else {
                imageProcessingFailed = true
                return
            }
            imageData = full
            thumbnailData = thumbnail
        } else {
            imageData = nil
            thumbnailData = nil
        }
        let input = draft.manualInput(
            source: image == nil ? .manual : .photo,
            imageData: imageData,
            thumbnailData: thumbnailData
        )
        writes.perform(
            operation: .addItem,
            write: { try WardrobeStore(modelContext: modelContext).addItem(input) },
            onSuccess: { dismiss() }
        )
    }
}
