import Foundation
import ImageIO
import UIKit

enum RemoteImageLoadError: Error, Equatable {
    case invalidResponse
    case unsuccessfulStatus(Int)
    case unsupportedContentType
    case downloadTooLarge
    case invalidImage
    case animatedImage
    case sourceDimensionsTooLarge
}

/// Loads validated image URLs into a small decoded-thumbnail cache. URLCache is
/// disabled so the only retained remote image data is the explicitly bounded
/// in-memory cache below. Redirects are rejected rather than following an
/// unvalidated destination.
actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let limits: RemoteImageLimits
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    init(limits: RemoteImageLimits = .production) {
        self.limits = limits

        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        session = URLSession(
            configuration: configuration,
            delegate: RemoteImageRedirectBlocker(),
            delegateQueue: nil
        )

        cache.countLimit = limits.cacheItemLimit
        cache.totalCostLimit = limits.cacheCostLimitBytes
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/webp,image/heic,image/jpeg,image/png", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        try RemoteImageResponseValidator.validate(response, limits: limits)

        var buffer = BoundedRemoteImageBuffer(
            maximumByteCount: limits.maximumDownloadBytes,
            expectedByteCount: response.expectedContentLength
        )
        for try await byte in bytes {
            try Task.checkCancellation()
            try buffer.append(byte)
        }
        let data = buffer.data
        let image = try RemoteImageDecoder.decodeThumbnail(data: data, limits: limits)
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
        cache.setObject(image, forKey: url as NSURL, cost: cost)
        return image
    }
}

enum RemoteImageResponseValidator {
    static func validate(
        _ response: URLResponse,
        limits: RemoteImageLimits
    ) throws(RemoteImageLoadError) {
        guard let http = response as? HTTPURLResponse else {
            throw .invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw .unsuccessfulStatus(http.statusCode)
        }
        guard limits.acceptsMIMEType(http.mimeType) else {
            throw .unsupportedContentType
        }
        if response.expectedContentLength > 0,
           !limits.acceptsDownload(byteCount: response.expectedContentLength) {
            throw .downloadTooLarge
        }
    }
}

struct BoundedRemoteImageBuffer {
    let maximumByteCount: Int
    private(set) var data: Data

    init(maximumByteCount: Int, expectedByteCount: Int64 = NSURLSessionTransferSizeUnknown) {
        self.maximumByteCount = max(0, maximumByteCount)
        data = Data()
        if expectedByteCount > 0 {
            let boundedExpectation = min(Int64(self.maximumByteCount), expectedByteCount)
            data.reserveCapacity(Int(boundedExpectation))
        }
    }

    mutating func append(_ byte: UInt8) throws(RemoteImageLoadError) {
        guard data.count < maximumByteCount else {
            throw .downloadTooLarge
        }
        data.append(byte)
    }
}

private final class RemoteImageRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

enum RemoteImageDecoder {
    static func decodeThumbnail(data: Data, limits: RemoteImageLimits) throws -> UIImage {
        guard limits.acceptsDownload(byteCount: Int64(data.count)),
              let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
              ) else {
            throw data.count > limits.maximumDownloadBytes
                ? RemoteImageLoadError.downloadTooLarge
                : RemoteImageLoadError.invalidImage
        }
        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else { throw RemoteImageLoadError.invalidImage }
        guard imageCount == 1 else { throw RemoteImageLoadError.animatedImage }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
            throw RemoteImageLoadError.invalidImage
        }
        guard limits.acceptsSource(width: width, height: height) else {
            throw RemoteImageLoadError.sourceDimensionsTooLarge
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limits.decodedThumbnailDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw RemoteImageLoadError.invalidImage
        }
        return UIImage(cgImage: cgImage)
    }
}
