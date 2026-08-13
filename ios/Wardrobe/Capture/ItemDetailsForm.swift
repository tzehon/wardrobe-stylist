import PhotosUI
import SwiftUI

/// One validated value model shared by manual add, ordinary edit, and imported
/// item review. The persistence inputs are derived here so every entry point
/// applies identical trimming, color parsing, price, and currency rules.
struct ItemDetailsDraft: Equatable {
    var name = ""
    var category = "top"
    var subcategory = ""
    var brand = ""
    var colors = ""
    var size = ""
    var material = ""
    var styleNotes = ""
    var includesPurchaseDate = false
    var purchaseDate = Date.now
    var purchasePrice = ""
    var purchaseCurrency = ""

    // Kept as part of the value draft for compatibility with the pure capture
    // tests. Image bytes remain view-owned and never enter text validation.
    var hasImage = false

    @MainActor
    init(item: Item, fallbackDate: Date = .now) {
        name = item.name
        category = item.category
        subcategory = item.subcategory ?? ""
        brand = item.brand ?? ""
        colors = item.colors.joined(separator: ", ")
        size = item.size ?? ""
        material = item.material ?? ""
        styleNotes = item.styleNotes ?? ""
        includesPurchaseDate = item.purchaseDate != nil
        purchaseDate = item.purchaseDate ?? fallbackDate
        purchasePrice = item.purchasePrice.map(Self.formatPrice) ?? ""
        purchaseCurrency = item.purchaseCurrency ?? ""
        hasImage = item.imageData != nil || item.thumbnailData != nil || item.imageURL != nil
    }

    init() {}

    var canSave: Bool {
        !name.trimmedRequired.isEmpty
            && !category.trimmedRequired.isEmpty
            && purchasePriceIsValid
            && purchaseCurrencyIsValid
    }

    var parsedColors: [String] {
        Self.parseColors(colors)
    }

    var parsedPrice: Double? {
        let value = purchasePrice.trimmedRequired
        guard !value.isEmpty else { return nil }
        return Double(value)
    }

    var normalizedCurrency: String? {
        purchaseCurrency.trimmedOptional?.uppercased()
    }

    var purchasePriceIsValid: Bool {
        let value = purchasePrice.trimmedRequired
        guard !value.isEmpty else { return true }
        guard let number = Double(value) else { return false }
        return number.isFinite && number >= 0
    }

    var purchaseCurrencyIsValid: Bool {
        guard let currency = normalizedCurrency else { return true }
        return currency.count == 3 && currency.unicodeScalars.allSatisfy {
            CharacterSet.uppercaseLetters.contains($0) && $0.isASCII
        }
    }

    static func parseColors(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func manualInput(
        source: ItemSource,
        imageData: Data?,
        thumbnailData: Data?
    ) -> ManualItemInput {
        ManualItemInput(
            name: name.trimmedRequired,
            category: category.trimmedRequired.lowercased(),
            subcategory: subcategory.trimmedOptional,
            brand: brand.trimmedOptional,
            colors: parsedColors,
            material: material.trimmedOptional,
            styleNotes: styleNotes.trimmedOptional,
            size: size.trimmedOptional,
            purchaseDate: includesPurchaseDate ? purchaseDate : nil,
            purchasePrice: parsedPrice,
            purchaseCurrency: normalizedCurrency,
            source: source,
            imageData: imageData,
            thumbnailData: thumbnailData
        )
    }

    func updateInput(
        imageUpdate: ItemImageUpdate = .unchanged,
        acceptPendingReview: Bool = false
    ) -> ItemUpdateInput {
        ItemUpdateInput(
            name: name.trimmedRequired,
            category: category.trimmedRequired.lowercased(),
            subcategory: subcategory.trimmedOptional,
            brand: brand.trimmedOptional,
            colors: parsedColors,
            material: material.trimmedOptional,
            styleNotes: styleNotes.trimmedOptional,
            size: size.trimmedOptional,
            purchaseDate: includesPurchaseDate ? purchaseDate : nil,
            purchasePrice: parsedPrice,
            purchaseCurrency: normalizedCurrency,
            imageUpdate: imageUpdate,
            acceptPendingReview: acceptPendingReview
        )
    }

    /// Compatibility accessor retained for focused edit-draft tests and simple
    /// callers that do not change the image or review state.
    var updateInput: ItemUpdateInput { updateInput() }

    private static func formatPrice(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }
}

typealias ItemDraft = ItemDetailsDraft
typealias ItemEditDraft = ItemDetailsDraft

struct ItemDetailsForm: View {
    @Binding var draft: ItemDetailsDraft
    let categories: [String]

    var body: some View {
        Section("Identity") {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("item.details.name")
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
            TextField("Size", text: $draft.size)
                .accessibilityIdentifier("item.details.size")
            TextField("Material", text: $draft.material)
            TextField("Style notes", text: $draft.styleNotes, axis: .vertical)
                .lineLimit(2...5)
        }

        Section {
            Toggle("Include purchase date", isOn: $draft.includesPurchaseDate)
            if draft.includesPurchaseDate {
                DatePicker(
                    "Purchased",
                    selection: $draft.purchaseDate,
                    displayedComponents: .date
                )
            }
            TextField("Price", text: $draft.purchasePrice)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("item.details.price")
            TextField("Currency (USD)", text: $draft.purchaseCurrency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .accessibilityIdentifier("item.details.currency")
        } header: {
            Text("Purchase")
        } footer: {
            if !draft.purchasePriceIsValid {
                Text("Enter a price of zero or more using digits and a decimal point.")
                    .foregroundStyle(.red)
            } else if !draft.purchaseCurrencyIsValid {
                Text("Use a three-letter currency code such as USD, EUR, or SGD.")
                    .foregroundStyle(.red)
            } else {
                Text("Purchase details stay on this device.")
            }
        }
    }
}

/// Shared optional-photo editor. An existing local or validated remote image is
/// preserved until the user explicitly replaces or removes it.
struct ItemPhotoEditor: View {
    @Binding var selectedImage: UIImage?
    @Binding var removesExistingImage: Bool
    let existingItem: Item?

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var imageLoadFailed = false

    private var hasExistingImage: Bool {
        guard let existingItem else { return false }
        return existingItem.imageData != nil
            || existingItem.thumbnailData != nil
            || existingItem.imageURL != nil
    }

    var body: some View {
        Section {
            preview
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
            if selectedImage != nil || (hasExistingImage && !removesExistingImage) {
                Button("Remove Image", role: .destructive) {
                    selectedImage = nil
                    removesExistingImage = true
                }
            }
        } header: {
            Text("Photo")
        } footer: {
            Text("Optional. Replacing an imported image stores your chosen copy locally.")
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { captured in
                selectedImage = captured
                removesExistingImage = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await loadPicked(newValue) }
        }
        .alert("Couldn’t Load Image", isPresented: $imageLoadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose a different image and try again.")
        }
    }

    @ViewBuilder private var preview: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 220)
                .clipShape(.rect(cornerRadius: 12))
        } else if let existingItem, hasExistingImage, !removesExistingImage {
            ItemThumbnail(item: existingItem)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else {
            imageLoadFailed = true
            return
        }
        selectedImage = loaded
        removesExistingImage = false
    }
}

extension String {
    var trimmedRequired: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOptional: String? {
        let value = trimmedRequired
        return value.isEmpty ? nil : value
    }
}
