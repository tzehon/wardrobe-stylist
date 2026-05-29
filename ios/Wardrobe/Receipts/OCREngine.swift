import CoreGraphics
import Foundation
@preconcurrency import Vision

/// Recognised text from one image, plus an averaged confidence over the
/// individual line observations. Downstream code can use `confidence` to
/// decide whether to trust the result or fall back to Claude in Tier 2.
struct OCRResult: Equatable, Sendable {
    var text: String
    var confidence: Double
}

/// Pluggable seam — production uses `VisionOCREngine`; tests can swap a stub.
protocol OCREngine: Sendable {
    func recognize(image: CGImage) async throws -> OCRResult
}

/// Vision-backed `OCREngine` using `VNRecognizeTextRequest`. Synchronous under
/// the hood (Vision's `perform` blocks), wrapped in `async` so callers don't
/// notice. Defaults to accurate + language correction; languages configurable.
struct VisionOCREngine: OCREngine {
    let recognitionLanguages: [String]
    let recognitionLevel: VNRequestTextRecognitionLevel
    let usesLanguageCorrection: Bool

    init(
        recognitionLanguages: [String] = ["en-US"],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
    }

    func recognize(image: CGImage) async throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        let observations = (request.results ?? []) as [VNRecognizedTextObservation]
        var lines: [String] = []
        var totalConfidence: Float = 0
        var counted = 0
        for observation in observations {
            guard let top = observation.topCandidates(1).first else { continue }
            lines.append(top.string)
            totalConfidence += top.confidence
            counted += 1
        }
        let avg = counted > 0 ? Double(totalConfidence) / Double(counted) : 0
        return OCRResult(
            text: lines.joined(separator: "\n"),
            confidence: avg
        )
    }
}
