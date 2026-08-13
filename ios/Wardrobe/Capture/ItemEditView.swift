import SwiftData
import SwiftUI

/// Editable value copy of a catalog item. Keeping text normalization outside
/// SwiftUI makes the correction path deterministic and independently tested.
struct ItemEditDraft: Equatable {
    var name: String
    var category: String
    var subcategory: String
    var brand: String
    var colors: String
    var material: String
    var styleNotes: String
    var includesPurchaseDate: Bool
    var purchaseDate: Date

    @MainActor
    init(item: Item, fallbackDate: Date = .now) {
        name = item.name
        category = item.category
        subcategory = item.subcategory ?? ""
        brand = item.brand ?? ""
        colors = item.colors.joined(separator: ", ")
        material = item.material ?? ""
        styleNotes = item.styleNotes ?? ""
        includesPurchaseDate = item.purchaseDate != nil
        purchaseDate = item.purchaseDate ?? fallbackDate
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var updateInput: ItemUpdateInput {
        ItemUpdateInput(
            name: name.trimmedRequired,
            category: category.trimmedRequired.lowercased(),
            subcategory: subcategory.trimmedOptional,
            brand: brand.trimmedOptional,
            colors: ItemDraft.parseColors(colors),
            material: material.trimmedOptional,
            styleNotes: styleNotes.trimmedOptional,
            purchaseDate: includesPurchaseDate ? purchaseDate : nil
        )
    }
}

struct ItemEditView: View {
    let item: Item

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isDemoMode) private var isDemoMode
    @State private var draft: ItemEditDraft
    @State private var writes = WardrobeWriteCoordinator()

    init(item: Item) {
        self.item = item
        _draft = State(initialValue: ItemEditDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isDemoMode {
                    Section {
                        DemoFictionalDataNotice()
                    }
                }

                if item.source == .email {
                    Section {
                        Label {
                            Text("Receipt details are a draft. Correct anything that doesn’t match the item you own.")
                        } icon: {
                            Image(systemName: "checklist")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Identity") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker("Category", selection: $draft.category) {
                        ForEach(categories, id: \.self) { category in
                            Text(CatalogCategoryStyle.title(category)).tag(category)
                        }
                    }
                    TextField("Subcategory", text: $draft.subcategory)
                    TextField("Brand", text: $draft.brand)
                }

                Section("Details") {
                    TextField("Colors (comma-separated)", text: $draft.colors)
                    TextField("Material", text: $draft.material)
                    TextField("Style notes", text: $draft.styleNotes, axis: .vertical)
                        .lineLimit(2...5)
                    Toggle("Include purchase date", isOn: $draft.includesPurchaseDate)
                    if draft.includesPurchaseDate {
                        DatePicker(
                            "Purchased",
                            selection: $draft.purchaseDate,
                            displayedComponents: .date
                        )
                    }
                }
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
            .wardrobePersistenceAlert(writes)
        }
    }

    private var categories: [String] {
        let normalized = item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              !CatalogOrganizer.canonicalOrder.contains(normalized) else {
            return CatalogOrganizer.canonicalOrder
        }
        return CatalogOrganizer.canonicalOrder + [normalized]
    }

    private func save() {
        guard draft.canSave else { return }
        writes.perform(
            operation: .updateItem,
            write: {
                try WardrobeStore(modelContext: modelContext)
                    .updateItem(item, with: draft.updateInput)
            },
            onSuccess: { dismiss() }
        )
    }
}

private extension String {
    var trimmedRequired: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOptional: String? {
        let value = trimmedRequired
        return value.isEmpty ? nil : value
    }
}
