import SwiftUI

extension View {
    /// Presents the same safe, actionable persistence error from every
    /// user-triggered wardrobe write surface.
    func wardrobePersistenceAlert(_ coordinator: WardrobeWriteCoordinator) -> some View {
        alert(
            coordinator.error?.title ?? "Couldn’t Save",
            isPresented: Binding(
                get: { coordinator.error != nil },
                set: { isPresented in
                    if !isPresented { coordinator.clearError() }
                }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.clearError() }
        } message: {
            Text(coordinator.error?.message ?? "Please try again.")
        }
    }
}
