import CoreGraphics
import Foundation
import ImageIO
import PDFKit

/// Tier 1 attachment-text extraction. PDF and image attachments on a receipt
/// email get turned into searchable text **on-device** so we can feed the
/// snippet (rather than the raw attachment) to the backend in Tier 2 — no
/// paid OCR API, no email content leaving the phone unnecessarily.
struct AttachmentOCR: Sendable {
    let engine: OCREngine
    /// Scale factor for PDF page rendering. 2x gives a clean bitmap for OCR
    /// at a reasonable memory cost on multi-page documents.
    let pdfRenderScale: CGFloat

    init(engine: OCREngine = VisionOCREngine(), pdfRenderScale: CGFloat = 2.0) {
        self.engine = engine
        self.pdfRenderScale = pdfRenderScale
    }

    /// Renders each PDF page to a bitmap, OCRs it, and concatenates the page
    /// texts with a blank-line separator. Returns "" if `data` isn't a PDF.
    func extractText(fromPDF data: Data) async throws -> String {
        guard let document = PDFDocument(data: data) else { return "" }
        var pages: [String] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i),
                  let image = renderPDF(page: page, scale: pdfRenderScale)
            else { continue }
            let result = try await engine.recognize(image: image)
            let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pages.append(trimmed) }
        }
        return pages.joined(separator: "\n\n")
    }

    /// Decodes any ImageIO-supported format (JPEG, PNG, HEIC, ...) and OCRs.
    /// Returns "" if `data` can't be decoded as an image.
    func extractText(fromImage data: Data) async throws -> String {
        guard let cgImage = decodeImage(data) else { return "" }
        let result = try await engine.recognize(image: cgImage)
        return result.text
    }

    // MARK: -

    private func renderPDF(page: PDFPage, scale: CGFloat) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int((bounds.width * scale).rounded())
        let height = Int((bounds.height * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        // Paint the background white so transparent PDFs don't OCR as noise.
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }

    private func decodeImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
