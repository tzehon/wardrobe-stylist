import SwiftData
import SwiftUI

/// Device-local catalog with explicit favorite and archive states. Archived
/// items stay recoverable but never enter styling.
struct CatalogView: View {
    let accountScope: WardrobeAccountScope
    var allowsAddingItems = true

    @Query(sort: \Item.name) private var storedItems: [Item]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedStatus: CatalogFilter.Status = .active
    @State private var sortOrder: CatalogSortOrder = .recent
    @State private var showingAddItem = false
    @State private var pendingDeletion: Item?
    @State private var writes = WardrobeWriteCoordinator()

    private var items: [Item] {
        WardrobeAccountFilter.visibleItems(from: storedItems, in: accountScope)
    }

    private var filteredItems: [Item] {
        CatalogFilter.apply(
            to: items,
            search: searchText,
            category: selectedCategory,
            status: selectedStatus
        )
    }

    private var sections: [CatalogSection<Item>] {
        CatalogOrganizer.sections(from: filteredItems, sortedBy: sortOrder)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyCatalog
            } else {
                ScrollView {
                    statusChips
                    categoryChips
                    if sections.isEmpty {
                        unavailableForCurrentFilter
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
        .sheet(isPresented: $showingAddItem) { AddItemView() }
        .confirmationDialog(
            "Delete this item?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDeletion)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let pendingDeletion {
                Text("“\(pendingDeletion.name)” will be removed from your catalog.")
            }
        }
        .wardrobePersistenceAlert(writes)
    }

    @ToolbarContentBuilder private var addButton: some ToolbarContent {
        if allowsAddingItems {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddItem = true } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .accessibilityIdentifier("wardrobe.addItem")
            }
        }
    }

    private var emptyCatalog: some View {
        ContentUnavailableView {
            Label("No items yet", systemImage: "square.grid.2x2")
        } description: {
            if allowsAddingItems {
                Text("Add your first piece manually or with a photo.")
            } else {
                Text("The fictional demo catalog is empty. Exit and reopen Demo Mode to restore its sample pieces.")
            }
        } actions: {
            if allowsAddingItems {
                Button("Add Item") { showingAddItem = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("wardrobe.empty.addItem")
            }
        }
    }

    private var unavailableForCurrentFilter: some View {
        ContentUnavailableView {
            Label(emptyFilterTitle, systemImage: emptyFilterSymbol)
        } description: {
            if !searchText.trimmedRequired.isEmpty {
                Text("No matching items in \(selectedStatus.label.lowercased()). Try another search or filter.")
            } else {
                Text(emptyFilterDescription)
            }
        } actions: {
            Button("Show Active") {
                searchText = ""
                selectedCategory = nil
                selectedStatus = .active
            }
        }
    }

    private var emptyFilterTitle: String {
        switch selectedStatus {
        case .active: "No matches"
        case .favorites: "No favorites yet"
        case .archived: "Archive is empty"
        }
    }

    private var emptyFilterSymbol: String {
        switch selectedStatus {
        case .active: "magnifyingglass"
        case .favorites: "star"
        case .archived: "archivebox"
        }
    }

    private var emptyFilterDescription: String {
        switch selectedStatus {
        case .active: "Try another category."
        case .favorites: "Mark frequently worn pieces with a star for quick access."
        case .archived: "Archived pieces appear here and can be restored at any time."
        }
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogFilter.Status.allCases) { status in
                    chip(
                        title: status.label,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = status
                        selectedCategory = nil
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .accessibilityIdentifier("catalog.statusFilters")
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(CatalogFilter.availableCategories(in: itemsForSelectedStatus), id: \.self) {
                    category in
                    chip(
                        title: CatalogCategoryStyle.title(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var itemsForSelectedStatus: [Item] {
        CatalogFilter.apply(to: items, search: "", category: nil, status: selectedStatus)
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
        CatalogGrid(
            sections: sections,
            accountScope: accountScope,
            onToggleFavorite: updateFavorite,
            onToggleArchive: updateArchive,
            onDelete: { pendingDeletion = $0 }
        )
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

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func store() -> WardrobeStore {
        WardrobeStore(modelContext: modelContext, accountScope: accountScope)
    }

    private func confirmDeletion() {
        guard let item = pendingDeletion else { return }
        pendingDeletion = nil
        writes.perform(operation: .deleteItem, write: { try store().deleteItem(item) })
    }

    private func updateFavorite(_ item: Item, to value: Bool) {
        writes.perform(operation: .updateItem, write: { try store().setFavorite(value, for: item) })
    }

    private func updateArchive(_ item: Item, to value: Bool) {
        writes.perform(operation: .updateItem, write: { try store().setArchived(value, for: item) })
    }

}

/// Kept outside `CatalogView` so Swift's result-builder type checker does not
/// have to solve the entire screen, nested navigation, and context menus as one
/// giant expression.
private struct CatalogGrid: View {
    let sections: [CatalogSection<Item>]
    let accountScope: WardrobeAccountScope
    let onToggleFavorite: (Item, Bool) -> Void
    let onToggleArchive: (Item, Bool) -> Void
    let onDelete: (Item) -> Void

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16, pinnedViews: [.sectionHeaders]) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        CatalogGridItem(
                            item: item,
                            accountScope: accountScope,
                            onToggleFavorite: onToggleFavorite,
                            onToggleArchive: onToggleArchive,
                            onDelete: onDelete
                        )
                    }
                } header: {
                    CatalogSectionHeader(category: section.category, count: section.items.count)
                }
            }
        }
    }
}

private struct CatalogGridItem: View {
    let item: Item
    let accountScope: WardrobeAccountScope
    let onToggleFavorite: (Item, Bool) -> Void
    let onToggleArchive: (Item, Bool) -> Void
    let onDelete: (Item) -> Void

    var body: some View {
        NavigationLink {
            ItemDetailView(item: item, accountScope: accountScope)
        } label: {
            CatalogCell(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wardrobe.item." + item.id.uuidString)
        .contextMenu {
            Button {
                onToggleFavorite(item, !item.isFavorite)
            } label: {
                Label(favoriteTitle, systemImage: item.isFavorite ? "star.slash" : "star")
            }
            Button {
                onToggleArchive(item, !item.isArchived)
            } label: {
                Label(archiveTitle, systemImage: item.isArchived ? "arrow.uturn.backward" : "archivebox")
            }
            Button(role: .destructive) { onDelete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var favoriteTitle: String { item.isFavorite ? "Remove Favorite" : "Favorite" }
    private var archiveTitle: String { item.isArchived ? "Restore" : "Archive" }
}

private struct CatalogSectionHeader: View {
    let category: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Label(CatalogCategoryStyle.title(category), systemImage: CatalogCategoryStyle.symbol(category))
                .font(.headline)
            Text("\(count)").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct CatalogCell: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ItemThumbnail(item: item)
                    .frame(height: 108)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12))
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .padding(8)
                        .accessibilityLabel("Favorite")
                }
            }

            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let brand = item.brand, !brand.isEmpty {
                Text(brand).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            if item.possibleDuplicateOfItemID != nil {
                Label("Possible duplicate", systemImage: "square.on.square")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if item.isArchived {
                Label("Archived", systemImage: "archivebox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ItemThumbnail: View {
    let item: Item

    var body: some View {
        if let data = item.thumbnailData ?? item.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Image(systemName: CatalogCategoryStyle.symbol(item.category))
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
        }
    }
}
