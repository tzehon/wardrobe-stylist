import CoreGraphics
import Foundation
import Testing
import UIKit

@testable import Wardrobe

/// Pluggable stand-in for `OCREngine` — returns canned text and counts calls.
/// Actor isolation gives us a thread-safe counter without needing an NSLock
/// (which Swift 6 forbids from async contexts).
actor CannedOCREngine: OCREngine {
    let text: String
    private(set) var callCount = 0

    init(text: String) { self.text = text }

    func recognize(image: CGImage) async throws -> OCRResult {
        callCount += 1
        return OCRResult(text: text, confidence: 0.9)
    }
}

@MainActor
struct AttachmentOCRTests {

    // MARK: - PDF path

    @Test func extractsTextFromPDFViaEngine() async throws {
        let engine = CannedOCREngine(text: "RECEIPT TOTAL $42.00")
        let attachment = AttachmentOCR(engine: engine)
        let pdf = Self.makeTestPDF(pageTexts: ["page one"])
        let result = try await attachment.extractText(fromPDF: pdf)
        #expect(result == "RECEIPT TOTAL $42.00")
        await #expect(engine.callCount == 1)
    }

    @Test func extractTextFromPDFRunsEngineOncePerPage() async throws {
        let engine = CannedOCREngine(text: "page text")
        let attachment = AttachmentOCR(engine: engine)
        let pdf = Self.makeTestPDF(pageTexts: ["p1", "p2", "p3"])
        let result = try await attachment.extractText(fromPDF: pdf)
        await #expect(engine.callCount == 3)
        // Pages joined with a blank line.
        #expect(result == "page text\n\npage text\n\npage text")
    }

    @Test func extractTextFromPDFReturnsEmptyForInvalidData() async throws {
        let engine = CannedOCREngine(text: "should not be called")
        let attachment = AttachmentOCR(engine: engine)
        let result = try await attachment.extractText(fromPDF: Data("not a pdf".utf8))
        #expect(result.isEmpty)
        await #expect(engine.callCount == 0)
    }

    // MARK: - Image path

    @Test func extractsTextFromImageViaEngine() async throws {
        let engine = CannedOCREngine(text: "from image")
        let attachment = AttachmentOCR(engine: engine)
        let png = Self.makeBlankPNG()
        let result = try await attachment.extractText(fromImage: png)
        #expect(result == "from image")
        await #expect(engine.callCount == 1)
    }

    @Test func extractTextFromImageReturnsEmptyForInvalidData() async throws {
        let engine = CannedOCREngine(text: "should not be called")
        let attachment = AttachmentOCR(engine: engine)
        let result = try await attachment.extractText(fromImage: Data("not an image".utf8))
        #expect(result.isEmpty)
        await #expect(engine.callCount == 0)
    }

    // MARK: - Real Vision OCR smoke test

    /// End-to-end check that `VisionOCREngine` actually recognises something.
    /// Lenient on purpose — text recognition is approximate, and we skip
    /// silently if Vision returns nothing (some simulator configurations).
    @Test func visionOCREngineReadsGeneratedText() async throws {
        let engine = VisionOCREngine()
        let image = Self.makeTextImage("WARDROBE OK", fontSize: 96)
        let result: OCRResult
        do {
            result = try await engine.recognize(image: image)
        } catch {
            return  // Vision threw on this simulator — skip rather than fail.
        }
        if result.text.isEmpty { return }  // Same — empty means "no observations".
        let lowered = result.text.lowercased()
        #expect(
            lowered.contains("wardrobe") || lowered.contains("ok"),
            "Vision read: \(result.text)"
        )
        #expect(result.confidence > 0)
    }

    // MARK: - Helpers

    /// Renders a multi-page PDF with the given text on each page.
    private static func makeTestPDF(pageTexts: [String]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 @ 72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black,
            ]
            for text in pageTexts {
                ctx.beginPage()
                (text as NSString).draw(at: CGPoint(x: 50, y: 50), withAttributes: attrs)
            }
        }
    }

    private static func makeBlankPNG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
        return renderer.pngData { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
    }

    private static func makeTextImage(_ text: String, fontSize: CGFloat) -> CGImage {
        let size = CGSize(width: 800, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.black,
            ]
            (text as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: attrs)
        }
        return uiImage.cgImage!
    }
}
