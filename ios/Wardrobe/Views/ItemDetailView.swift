import SwiftData
import SwiftUI

struct ItemDetailView: View {
    let item: Item
    let accountScope: WardrobeAccountScope

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isDemoMode) private var isDemoMode
    @State private var confirmingDelete = false
    @State private var showingEdit = false
    @State private var isDeleting = false
    @State private var writes = WardrobeWriteCoordinator()

    init(item: Item, accountScope: WardrobeAccountScope = .deviceLocal) {
        self.item = item
        self.accountScope = accountScope
    }

    var body: some View {
        Group {
            if isDeleting {
                ProgressView("Deleting item…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Item")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                itemDetails
            }
        }
        .wardrobePersistenceAlert(writes)
    }

    private var itemDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.title2.weight(.semibold))
                        if let brand = item.brand, !brand.isEmpty {
                            Text(brand).font(.headline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button { updateFavorite(to: !item.isFavorite) } label: {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(item.isFavorite ? "Remove favorite" : "Add favorite")
                    .accessibilityIdentifier("item.detail.favorite")
                }

                if !item.colors.isEmpty { colorsRow }
                attributes
                if let notes = item.styleNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes").font(.subheadline.weight(.semibold))
                        Text(notes).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEdit = true
                }
                .accessibilityIdentifier("item.detail.edit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { updateArchive(to: !item.isArchived) } label: {
                        Label(item.isArchived ? "Restore" : "Archive", systemImage: item.isArchived ? "arrow.uturn.backward" : "archivebox")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("item.detail.more")
            }
        }
        .sheet(isPresented: $showingEdit) {
            ItemEditView(item: item, accountScope: accountScope)
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                // Stop rendering persisted properties before SwiftData
                // invalidates the deleted model. The failed-write path rolls
                // back and restores this screen; success dismisses it.
                isDeleting = true
                writes.perform(
                    operation: .deleteItem,
                    write: { try store().deleteItem(item) },
                    onSuccess: { dismiss() }
                )
                if writes.error != nil {
                    isDeleting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isDemoMode
                ? "“\(item.name)” will be removed from this disposable demo catalog."
                : "“\(item.name)” will be removed from your catalog.")
        }
    }

    private var hero: some View {
        ItemThumbnail(item: item)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))
    }

    private var colorsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Colors").font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(item.colors, id: \.self) { ColorChip(value: $0) }
            }
        }
    }

    @ViewBuilder private var attributes: some View {
        VStack(spacing: 0) {
            AttributeRow(label: "Category", value: CatalogCategoryStyle.title(item.category))
            if let sub = item.subcategory, !sub.isEmpty { rowDivider; AttributeRow(label: "Subcategory", value: sub.capitalized) }
            if let size = item.size, !size.isEmpty { rowDivider; AttributeRow(label: "Size", value: size) }
            if let material = item.material, !material.isEmpty { rowDivider; AttributeRow(label: "Material", value: material) }
            if let purchased = item.purchaseDate { rowDivider; AttributeRow(label: "Purchased", value: purchased.formatted(date: .abbreviated, time: .omitted)) }
            if let price = purchasePriceLabel { rowDivider; AttributeRow(label: "Price", value: price) }
            rowDivider
            AttributeRow(label: "Source", value: sourceLabel)
            rowDivider
            AttributeRow(label: "Status", value: statusLabel)
        }
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var rowDivider: some View { Divider() }

    private var purchasePriceLabel: String? {
        guard let value = item.purchasePrice else { return nil }
        let amount = value.formatted(.number.precision(.fractionLength(2)))
        return [item.purchaseCurrency, amount].compactMap { $0 }.joined(separator: " ")
    }

    private var statusLabel: String {
        if item.isArchived { return "Archived" }
        return "Active"
    }

    private var sourceLabel: String {
        switch item.source {
        case .photo: "Photo"
        case .manual: "Added manually"
        }
    }

    private func store() -> WardrobeStore {
        WardrobeStore(modelContext: modelContext, accountScope: accountScope)
    }

    private func updateFavorite(to value: Bool) {
        writes.perform(operation: .updateItem, write: { try store().setFavorite(value, for: item) })
    }

    private func updateArchive(to value: Bool) {
        writes.perform(operation: .updateItem, write: { try store().setArchived(value, for: item) })
    }
}

private struct AttributeRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct ColorChip: View {
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            if let color = Color(hexString: value) {
                Circle().fill(color).frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.quaternary))
            }
            Text(value).font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(.capsule)
    }
}

extension Color {
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
