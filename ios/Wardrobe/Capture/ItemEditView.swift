import SwiftData
import SwiftUI

/// Shared edit/review flow. Pending receipt imports use the same complete form
/// as manual items, but the final action explicitly accepts the checked data.
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

                if item.reviewState == .pendingReview {
                    reviewNotice
                }

                ItemPhotoEditor(
                    selectedImage: $replacementImage,
                    removesExistingImage: $removesExistingImage,
                    existingItem: item,
                    coordinator: photoPicker
                )
                ItemDetailsForm(draft: $draft, categories: categories)
            }
            .navigationTitle(item.reviewState == .pendingReview ? "Review Import" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item.reviewState == .pendingReview ? "Accept" : "Save", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier(
                            item.reviewState == .pendingReview
                                ? "item.review.accept"
                                : "item.edit.save"
                        )
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

    private var reviewNotice: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check every imported detail")
                        .font(.subheadline.weight(.semibold))
                    Text("Receipt extraction can make mistakes. Accept only after the item, size, purchase details, and image match what you own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checklist")
            }
            if let confidence = item.extractionConfidence {
                LabeledContent("Extraction confidence", value: confidence.label)
                    .accessibilityIdentifier("item.review.confidence")
            }
            if item.possibleDuplicateOfItemID != nil {
                Label("Possible duplicate: compare this with the similar imported item before accepting.", systemImage: "square.on.square")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
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

        let input = draft.updateInput(
            imageUpdate: imageUpdate,
            acceptPendingReview: item.reviewState == .pendingReview
        )
        writes.perform(
            operation: .updateItem,
            write: {
                try WardrobeStore(modelContext: modelContext, accountScope: accountScope)
                    .updateItem(item, with: input)
            },
            onSuccess: { dismiss() }
        )
    }
}

extension ItemExtractionConfidence {
    var label: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}
