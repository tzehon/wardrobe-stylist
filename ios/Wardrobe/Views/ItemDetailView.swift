import SwiftData
import SwiftUI

/// Read-only detail for a single catalog item. Editing/curation comes later
/// (Phase 4 photo capture, Phase 5 stylist); for the MVP this just surfaces
/// everything the extraction pipeline captured, including the audit trail.
struct ItemDetailView: View {
    let item: Item

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.title2.weight(.semibold))
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand).font(.headline).foregroundStyle(.secondary)
                    }
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
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                dismiss()
                modelContext.delete(item)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(item.name)” will be removed from your catalog.")
        }
    }

    // MARK: - Sections

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
                ForEach(item.colors, id: \.self) { color in
                    ColorChip(value: color)
                }
            }
        }
    }

    @ViewBuilder private var attributes: some View {
        VStack(spacing: 0) {
            AttributeRow(label: "Category", value: CatalogCategoryStyle.title(item.category))
            if let sub = item.subcategory, !sub.isEmpty {
                Divider()
                AttributeRow(label: "Subcategory", value: sub.capitalized)
            }
            if let material = item.material, !material.isEmpty {
                Divider()
                AttributeRow(label: "Material", value: material)
            }
            if let purchased = item.purchaseDate {
                Divider()
                AttributeRow(
                    label: "Purchased",
                    value: purchased.formatted(date: .abbreviated, time: .omitted)
                )
            }
            Divider()
            AttributeRow(label: "Source", value: sourceLabel)
        }
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var sourceLabel: String {
        switch item.source {
        case .email:  return "Email receipt"
        case .photo:  return "Photo"
        case .manual: return "Added manually"
        }
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

/// A color value (hex like `#1A2B3C` or a plain name): shows a swatch when it
/// parses as hex, with the raw text alongside.
private struct ColorChip: View {
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            if let color = Color(hexString: value) {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.quaternary))
            }
            Text(value)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(.capsule)
    }
}

extension Color {
    /// Parses `#RRGGBB` or `RRGGBB`; returns nil for names or malformed input.
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
