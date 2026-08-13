import PhotosUI
import SwiftData
import SwiftUI

/// Editable draft for a manually-added item. Pulled out of the view so the
/// validation + color parsing are pure and unit-testable.
struct ItemDraft {
    var name = ""
    var category = "top"
    var brand = ""
    var colors = ""        // comma-separated user input
    var material = ""
    var hasImage = false

    /// A name is the only required field. Photos make the wardrobe richer but
    /// are optional so the local-first experience never depends on camera or
    /// photo-library permission.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var parsedColors: [String] {
        Self.parseColors(colors)
    }

    static func parseColors(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Add a local item with optional photo capture. Items without a photo are
/// stored as manual entries and receive a category illustration in the catalog.
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ItemDraft()
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var writes = WardrobeWriteCoordinator()

    private static let categories = CatalogOrganizer.canonicalOrder

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoSection
                } header: {
                    Text("Photo")
                } footer: {
                    Text("Optional. You can add the item now and use its category illustration.")
                }
                Section("Details") {
                    TextField("Name", text: $draft.name)
                    Picker("Category", selection: $draft.category) {
                        ForEach(Self.categories, id: \.self) { category in
                            Text(CatalogCategoryStyle.title(category)).tag(category)
                        }
                    }
                    TextField("Brand", text: $draft.brand)
                    TextField("Colors (comma-separated)", text: $draft.colors)
                    TextField("Material", text: $draft.material)
                }
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
            .sheet(isPresented: $showingCamera) {
                CameraPicker { captured in
                    image = captured
                    draft.hasImage = true
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, newValue in
                Task { await loadPicked(newValue) }
            }
            .wardrobePersistenceAlert(writes)
        }
    }

    @ViewBuilder private var photoSection: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 220)
                .clipShape(.rect(cornerRadius: 12))
        }
        HStack(spacing: 16) {
            if CameraPicker.isAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else { return }
        image = loaded
        draft.hasImage = true
    }

    private func save() {
        let input = ManualItemInput(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category,
            brand: draft.brand.trimmedNonEmpty,
            colors: draft.parsedColors,
            material: draft.material.trimmedNonEmpty,
            source: image == nil ? .manual : .photo,
            imageData: image.flatMap { ImageProcessor.imageData(from: $0) },
            thumbnailData: image.flatMap { ImageProcessor.thumbnailData(from: $0) }
        )
        writes.perform(
            operation: .addItem,
            write: { try WardrobeStore(modelContext: modelContext).addItem(input) },
            onSuccess: { dismiss() }
        )
    }
}

private extension String {
    /// Trimmed, or `nil` when empty — for optional `Item` fields.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
