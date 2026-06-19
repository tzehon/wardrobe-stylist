import SwiftData
import SwiftUI

/// Phase 3: browse the wardrobe catalog — grouped into dynamic category
/// sections, with search, category filtering, sorting, and delete. Grouping /
/// filtering / ordering is delegated to the pure `CatalogOrganizer` /
/// `CatalogFilter` (unit-tested separately); this view is just presentation.
struct CatalogView: View {
    @Query(sort: \Item.name) private var items: [Item]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedCategory: String?      // nil = all categories
    @State private var sortOrder: CatalogSortOrder = .recent
    @State private var showingAddItem = false

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    private var sections: [CatalogSection<Item>] {
        let filtered = CatalogFilter.apply(
            to: items, search: searchText, category: selectedCategory
        )
        return CatalogOrganizer.sections(from: filtered, sortedBy: sortOrder)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyCatalog
            } else {
                ScrollView {
                    categoryChips
                    if sections.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 48)
                    } else {
                        grid
                    }
                }
            }
        }
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search name or brand")
        .toolbar {
            sortMenu
            addButton
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
    }

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
            }
        }
    }

    // MARK: - Pieces

    private var emptyCatalog: some View {
        ContentUnavailableView {
            Label("No items yet", systemImage: "square.grid.2x2")
        } description: {
            Text("Sync your Gmail receipts or add items to start building your catalog.")
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(CatalogFilter.availableCategories(in: items), id: \.self) { category in
                    chip(title: CatalogCategoryStyle.title(category),
                         isSelected: selectedCategory == category) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 16, pinnedViews: [.sectionHeaders]) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            CatalogCell(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    CatalogSectionHeader(category: section.category, count: section.items.count)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(CatalogSortOrder.allCases) { order in
                        Label(order.label, systemImage: order.symbol).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    private func delete(_ item: Item) {
        modelContext.delete(item)
        try? modelContext.save()
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

/// Renders, in priority order: a stored local image (Phase 4 photo capture), a
/// remote product image from the receipt (`imageURL`, loaded via `AsyncImage`),
/// or a category-symbol placeholder.
struct ItemThumbnail: View {
    let item: Item

    var body: some View {
        if let data = item.thumbnailData ?? item.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let urlString = item.imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image): image.resizable().scaledToFill()
                case .failure:            placeholder
                case .empty:              ProgressView()
                @unknown default:         placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: CatalogCategoryStyle.symbol(item.category))
            .font(.system(size: 30))
            .foregroundStyle(.secondary)
    }
}
