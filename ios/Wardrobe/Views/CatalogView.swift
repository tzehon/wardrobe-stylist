import SwiftData
import SwiftUI

/// Phase 3 (MVP): browse the wardrobe catalog, grouped into dynamic category
/// sections. Pulls items straight from SwiftData via `@Query`; grouping/order is
/// delegated to the pure `CatalogOrganizer` (unit-tested separately).
struct CatalogView: View {
    @Query(sort: \Item.name) private var items: [Item]

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No items yet", systemImage: "square.grid.2x2")
                } description: {
                    Text("Sync your Gmail receipts or add items to start building your catalog.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(CatalogOrganizer.sections(from: items)) { section in
                            Section {
                                ForEach(section.items) { item in
                                    NavigationLink {
                                        ItemDetailView(item: item)
                                    } label: {
                                        CatalogCell(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                CatalogSectionHeader(
                                    category: section.category,
                                    count: section.items.count
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Pinned section header: pluralized category title + item count, on a solid
/// background so grid cells don't show through when it sticks.
private struct CatalogSectionHeader: View {
    let category: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Label(CatalogCategoryStyle.title(category),
                  systemImage: CatalogCategoryStyle.symbol(category))
                .font(.headline)
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }
}

/// One grid cell: thumbnail (or category placeholder) above name + brand.
private struct CatalogCell: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ItemThumbnail(item: item)
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))

            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let brand = item.brand, !brand.isEmpty {
                Text(brand)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Renders the item's stored thumbnail/image if present, else a category-symbol
/// placeholder. Email-sourced items have no image until Phase 4 (photo capture),
/// so the placeholder is the common case today.
struct ItemThumbnail: View {
    let item: Item

    var body: some View {
        if let data = item.thumbnailData ?? item.imageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: CatalogCategoryStyle.symbol(item.category))
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
        }
    }
}
