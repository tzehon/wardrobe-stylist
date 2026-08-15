import Observation
import PhotosUI
import SwiftUI
import UIKit

enum ItemPhotoSource: Equatable, Sendable {
    case camera
    case library
}

/// Presentation state for the two mutually-exclusive photo sources.
///
/// This object is owned by Add/Edit rather than by a `Section` inside a
/// `Form`. Form rows are free to be recreated while UIKit presents a picker;
/// keeping the source state at the stable navigation root prevents that row
/// recreation from resetting the binding and immediately dismissing the
/// camera or library.
@MainActor
@Observable
final class ItemPhotoPickerCoordinator {
    private(set) var presentedSource: ItemPhotoSource?
    var pickerItem: PhotosPickerItem?
    private(set) var imageLoadFailed = false

    func present(_ source: ItemPhotoSource) {
        guard presentedSource == nil else { return }
        presentedSource = source
    }

    func updatePresentation(_ isPresented: Bool, for source: ItemPhotoSource) {
        if isPresented {
            present(source)
        } else if presentedSource == source {
            presentedSource = nil
        }
    }

    func markImageLoadFailed() {
        imageLoadFailed = true
    }

    func clearImageLoadFailure() {
        imageLoadFailed = false
    }
}

extension View {
    /// Hosts UIKit/PhotosUI presentation at the stable Add/Edit navigation
    /// root. `ItemPhotoEditor` only sends source-selection intents.
    func itemPhotoPicker(
        coordinator: ItemPhotoPickerCoordinator,
        selectedImage: Binding<UIImage?>,
        removesExistingImage: Binding<Bool>
    ) -> some View {
        modifier(
            ItemPhotoPickerPresenter(
                coordinator: coordinator,
                selectedImage: selectedImage,
                removesExistingImage: removesExistingImage
            )
        )
    }
}

private struct ItemPhotoPickerPresenter: ViewModifier {
    @Bindable var coordinator: ItemPhotoPickerCoordinator
    @Binding var selectedImage: UIImage?
    @Binding var removesExistingImage: Bool

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: presentationBinding(for: .camera)) {
                CameraPicker { captured in
                    selectedImage = captured
                    removesExistingImage = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: presentationBinding(for: .library),
                selection: $coordinator.pickerItem,
                matching: .images
            )
            .onChange(of: coordinator.pickerItem) { _, newValue in
                Task { await loadPicked(newValue) }
            }
            .alert("Couldn’t Load Image", isPresented: imageLoadFailureBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a different image and try again.")
            }
    }

    private func presentationBinding(for source: ItemPhotoSource) -> Binding<Bool> {
        Binding(
            get: { coordinator.presentedSource == source },
            set: { coordinator.updatePresentation($0, for: source) }
        )
    }

    private var imageLoadFailureBinding: Binding<Bool> {
        Binding(
            get: { coordinator.imageLoadFailed },
            set: { isPresented in
                if !isPresented { coordinator.clearImageLoadFailure() }
            }
        )
    }

    @MainActor
    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { coordinator.pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else {
            coordinator.markImageLoadFailed()
            return
        }
        selectedImage = loaded
        removesExistingImage = false
    }
}
