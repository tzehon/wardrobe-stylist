import Testing
@testable import Wardrobe

@MainActor
@Suite("Item photo picker coordinator")
struct ItemPhotoPickerCoordinatorTests {
    @Test("Camera and library presentations are mutually exclusive")
    func sourcesAreMutuallyExclusive() {
        let coordinator = ItemPhotoPickerCoordinator()

        coordinator.present(.camera)
        coordinator.present(.library)

        #expect(coordinator.presentedSource == .camera)
    }

    @Test("A dismissed source can be followed by the other source")
    func sourceCanChangeAfterDismissal() {
        let coordinator = ItemPhotoPickerCoordinator()

        coordinator.present(.camera)
        coordinator.updatePresentation(false, for: .camera)
        coordinator.present(.library)

        #expect(coordinator.presentedSource == .library)
    }

    @Test("A stale dismissal cannot close the active picker")
    func staleDismissalDoesNotCloseActiveSource() {
        let coordinator = ItemPhotoPickerCoordinator()

        coordinator.present(.camera)
        coordinator.updatePresentation(false, for: .camera)
        coordinator.present(.library)
        coordinator.updatePresentation(false, for: .camera)

        #expect(coordinator.presentedSource == .library)
    }

    @Test("Image-load errors are explicitly recoverable")
    func imageLoadFailureCanBeCleared() {
        let coordinator = ItemPhotoPickerCoordinator()

        coordinator.markImageLoadFailed()
        #expect(coordinator.imageLoadFailed)

        coordinator.clearImageLoadFailure()
        #expect(!coordinator.imageLoadFailed)
    }
}
