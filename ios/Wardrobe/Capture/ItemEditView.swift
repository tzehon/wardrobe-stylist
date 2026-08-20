import SwiftData
import SwiftUI

struct ItemEditView: View {
    let item: Item
    let accountScope: WardrobeAccountScope

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isDemoMode) private var isDemoMode
    @State private var draft: ItemDetailsDraft
    @State private var replacementImage: UIImage?
    @State private var removesExistingImage = false
    @State private var imageProcessingFailed = false
    @State private var writes = WardrobeWriteCoordinator()
    @State private var photoPicker = ItemPhotoPickerCoordinator()

    init(item: Item, accountScope: WardrobeAccountScope = .deviceLocal) {
        self.item = item
        self.accountScope = accountScope
        _draft = State(initialValue: ItemDetailsDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isDemoMode {
                    Section { DemoFictionalDataNotice() }
                }

                ItemPhotoEditor(
                    selectedImage: $replacementImage,
                    removesExistingImage: $removesExistingImage,
                    existingItem: item,
                    coordinator: photoPicker
                )
                ItemDetailsForm(draft: $draft, categories: categories)
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier("item.edit.save")
                }
            }
            .alert("Couldn’t Prepare Image", isPresented: $imageProcessingFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a different image and try again. No changes were saved.")
            }
            .wardrobePersistenceAlert(writes)
        }
        .itemPhotoPicker(
            coordinator: photoPicker,
            selectedImage: $replacementImage,
            removesExistingImage: $removesExistingImage
        )
    }

    private var categories: [String] {
        let normalized = item.category.trimmedRequired.lowercased()
        guard !normalized.isEmpty,
              !CatalogOrganizer.canonicalOrder.contains(normalized) else {
            return CatalogOrganizer.canonicalOrder
        }
        return CatalogOrganizer.canonicalOrder + [normalized]
    }

    private func save() {
        guard draft.canSave else { return }
        let imageUpdate: ItemImageUpdate
        if let replacementImage {
            guard let full = ImageProcessor.imageData(from: replacementImage),
                  let thumbnail = ImageProcessor.thumbnailData(from: replacementImage) else {
                imageProcessingFailed = true
                return
            }
            imageUpdate = .replace(imageData: full, thumbnailData: thumbnail)
        } else if removesExistingImage {
            imageUpdate = .remove
        } else {
            imageUpdate = .unchanged
        }

        writes.perform(
            operation: .updateItem,
            write: {
                try WardrobeStore(modelContext: modelContext, accountScope: accountScope)
                    .updateItem(item, with: draft.updateInput(imageUpdate: imageUpdate))
            },
            onSuccess: { dismiss() }
        )
    }
}
