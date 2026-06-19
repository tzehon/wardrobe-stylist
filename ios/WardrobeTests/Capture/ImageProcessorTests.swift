import Foundation
import Testing
import UIKit

@testable import Wardrobe

struct ImageProcessorTests {

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.systemBlue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    @Test func downscaleFitsWithinMaxAndPreservesAspect() {
        let source = makeImage(width: 1000, height: 500)
        let out = ImageProcessor.downscaled(source, maxDimension: 400)
        #expect(max(out.size.width, out.size.height) <= 400 + 0.5)
        #expect(abs(out.size.width / out.size.height - 2.0) < 0.01)  // 2:1 preserved
    }

    @Test func downscaleNeverUpscales() {
        let source = makeImage(width: 120, height: 80)
        let out = ImageProcessor.downscaled(source, maxDimension: 400)
        #expect(out.size == source.size)
    }

    @Test func thumbnailDataDecodesAndIsBounded() {
        let source = makeImage(width: 1200, height: 900)
        let data = ImageProcessor.thumbnailData(from: source, maxDimension: 300)
        #expect(data != nil)
        let decoded = data.flatMap(UIImage.init(data:))
        #expect(decoded != nil)
        if let decoded {
            #expect(max(decoded.size.width, decoded.size.height) <= 300 + 0.5)
        }
    }
}
