import UIKit

/// Pure image helpers for catalog photos: an aspect-preserving downscale plus
/// JPEG encoders for a small thumbnail and a reasonably-sized full image.
///
/// UIKit rendering only — these run fine in the simulator, unlike the Vision
/// feature-print / subject-lift paths (which are device-only). No Vision here:
/// Phase 4's scope is capture + thumbnail, not background removal or dedup.
enum ImageProcessor {

    /// JPEG data for a small catalog thumbnail.
    static func thumbnailData(
        from image: UIImage,
        maxDimension: CGFloat = 400,
        quality: CGFloat = 0.8
    ) -> Data? {
        downscaled(image, maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    /// JPEG data for the stored full image (bounded so we don't persist 12MP originals).
    static func imageData(
        from image: UIImage,
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.85
    ) -> Data? {
        downscaled(image, maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    /// Aspect-preserving downscale so the longest side is at most `maxDimension`.
    /// Never upscales. Renders at scale 1 so the result's `size` is in pixels.
    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let factor = maxDimension / longest
        let target = CGSize(width: size.width * factor, height: size.height * factor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
