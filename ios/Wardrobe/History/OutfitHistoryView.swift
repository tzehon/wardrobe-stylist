import SwiftData
import SwiftUI

struct OutfitHistoryView: View {
    let accountScope: WardrobeAccountScope

    @Query(sort: \Outfit.createdAt, order: .reverse)
    private var storedOutfits: [Outfit]
    @Query private var storedItems: [Item]
    @Query private var storedWearLogs: [WearLog]

    private var days: [OutfitHistoryDay] {
        OutfitHistoryOrganizer.days(from: storedOutfits, in: accountScope)
    }

    private var insights: WardrobeInsightsSnapshot {
        WardrobeInsights.make(
            items: storedItems,
            outfits: storedOutfits,
            wearLogs: storedWearLogs,
            in: accountScope
        )
    }

    var body: some View {
        List {
            Section("Wardrobe snapshot") {
                LabeledContent("Looks worn", value: "\(insights.looksWorn)")
                LabeledContent("Pieces in rotation", value: "\(insights.piecesWorn)")
                LabeledContent("Not worn yet", value: "\(insights.unwornPieces)")
                LabeledContent("Favorites", value: "\(insights.favorites)")
                ForEach(insights.mostWorn) { ranked in
                    NavigationLink {
                        ItemDetailView(
                            item: ranked.item,
                            accountScope: accountScope
                        )
                    } label: {
                        LabeledContent(
                            ranked.item.name,
                            value: "\(ranked.wearCount) wear\(ranked.wearCount == 1 ? "" : "s")"
                        )
                    }
                }
            }

            if days.isEmpty {
                Section {
                ContentUnavailableView {
                    Label("No worn looks yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("When you choose “Wear this” in Today, the look and its pieces will appear here.")
                }
                }
            } else {
                ForEach(days) { day in
                    Section {
                        ForEach(day.outfits) { outfit in
                            NavigationLink {
                                OutfitHistoryDetailView(
                                    outfit: outfit,
                                    accountScope: accountScope
                                )
                            } label: {
                                OutfitHistoryRow(outfit: outfit)
                            }
                            .accessibilityIdentifier("history.outfit.\(outfit.id.uuidString)")
                        }
                    } header: {
                        Text(day.date.formatted(date: .complete, time: .omitted))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.root")
    }
}

private struct OutfitHistoryRow: View {
    let outfit: Outfit

    private var title: String {
        let trimmed = outfit.occasion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Worn look" : trimmed.capitalized
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OutfitHistoryThumbnailStrip(items: outfit.items, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                Text(outfit.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(itemSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(outfit.items.count) pieces: \(itemSummary), worn \(outfit.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }

    private var itemSummary: String {
        let names = outfit.items.map(\.name).sorted()
        return names.isEmpty ? "No pieces available" : names.joined(separator: ", ")
    }
}

private struct OutfitHistoryDetailView: View {
    let outfit: Outfit
    let accountScope: WardrobeAccountScope

    @Environment(\.modelContext) private var modelContext
    @Query private var wearLogs: [WearLog]
    @State private var writes = WardrobeWriteCoordinator()

    private var title: String {
        let trimmed = outfit.occasion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Worn Look" : trimmed.capitalized
    }

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "Worn",
                    value: outfit.createdAt.formatted(date: .complete, time: .shortened)
                )
                if let colorStory = nonempty(outfit.colorStory) {
                    LabeledContent("Color story", value: colorStory)
                }
            }

            if let rationale = nonempty(outfit.rationale) {
                Section("Why it worked") {
                    Text(rationale)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Your feedback") {
                Text("Rate this worn look. Aria uses the item ratings as a soft preference in future suggestions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            saveRating(rating)
                        } label: {
                            Image(systemName: rating <= currentRating ? "star.fill" : "star")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Rate \(rating) out of 5")
                        .accessibilityValue(rating == currentRating ? "Selected" : "Not selected")
                        .accessibilityIdentifier("history.rating.\(rating)")
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section("Pieces") {
                if outfit.items.isEmpty {
                    Text("These pieces are no longer in your wardrobe.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(outfit.items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { item in
                        NavigationLink {
                            ItemDetailView(item: item, accountScope: accountScope)
                        } label: {
                            HStack(spacing: 12) {
                                ItemThumbnail(item: item)
                                    .frame(width: 56, height: 56)
                                    .clipShape(.rect(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text(CatalogCategoryStyle.title(item.category))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .wardrobePersistenceAlert(writes)
    }

    private var currentRating: Int {
        wearLogs.first {
            $0.outfit?.id == outfit.id
                && WardrobeAccountFilter.isVisible($0, in: accountScope)
        }?.feedback ?? 0
    }

    private func saveRating(_ rating: Int) {
        writes.perform(
            operation: .rateOutfit,
            write: {
                try WardrobeStore(
                    modelContext: modelContext,
                    accountScope: accountScope
                ).rateOutfit(outfit, feedback: rating)
            }
        )
    }

    private func nonempty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OutfitHistoryThumbnailStrip: View {
    let items: [Item]
    let size: CGFloat

    var body: some View {
        HStack(spacing: -size * 0.38) {
            ForEach(Array(items.prefix(3))) { item in
                ItemThumbnail(item: item)
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: size * 0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.18)
                            .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                    }
            }
            if items.isEmpty {
                Image(systemName: "hanger")
                    .frame(width: size, height: size)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: size * 0.18))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}
