import SwiftUI
import UIKit

/// Product-image view that never sends a request until the untrusted receipt
/// URL passes `RemoteImagePolicy`. Failure remains a useful, accessible
/// category placeholder instead of exposing raw network errors.
struct SafeRemoteImage: View {
    private enum Phase {
        case placeholder
        case loading
        case success(UIImage)
        case failure
    }

    let urlString: String
    let placeholderSystemName: String
    var policy: RemoteImagePolicy = .production

    @State private var phase: Phase = .placeholder

    var body: some View {
        ZStack {
            switch phase {
            case .placeholder:
                placeholder
            case .loading:
                placeholder.opacity(0.35)
                ProgressView()
            case let .success(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.caption)
                    .padding(6)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .task(id: urlString) {
            await load()
        }
    }

    private var placeholder: some View {
        Image(systemName: placeholderSystemName)
            .font(.system(size: 30))
            .foregroundStyle(.secondary)
    }

    private var accessibilityLabel: String {
        switch phase {
        case .placeholder: return "Product image unavailable. Showing category placeholder."
        case .loading: return "Loading product image."
        case .success: return "Product image."
        case .failure: return "Product image could not be loaded. Showing category placeholder."
        }
    }

    @MainActor
    private func load() async {
        phase = .loading
        do {
            let url = try policy.validatedURL(from: urlString)
            let image = try await RemoteImageLoader.shared.image(for: url)
            try Task.checkCancellation()
            phase = .success(image)
        } catch is CancellationError {
            phase = .placeholder
        } catch {
            phase = .failure
        }
    }
}
