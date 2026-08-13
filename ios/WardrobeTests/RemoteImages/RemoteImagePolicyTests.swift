import Foundation
import ImageIO
import Testing
import UIKit
@testable import Wardrobe

@Suite("Remote image URL policy")
struct RemoteImagePolicyTests {
    private let policy = RemoteImagePolicy(
        allowedHostSuffixes: ["cdn.shopify.com", "images.example-cdn.com"]
    )

    @Test func acceptsReviewedHTTPSOriginsAndCDNSubdomains() throws {
        #expect(try policy.validatedURL(from: "https://cdn.shopify.com/s/files/item.jpg").host == "cdn.shopify.com")
        #expect(try policy.validatedURL(from: "https://resize.images.example-cdn.com/a.png?w=600").host == "resize.images.example-cdn.com")
    }

    @Test(arguments: [
        "http://cdn.shopify.com/item.jpg",
        "ftp://cdn.shopify.com/item.jpg",
        "javascript:alert(1)",
        "//cdn.shopify.com/item.jpg"
    ])
    func rejectsAnythingOtherThanHTTPS(_ rawValue: String) {
        #expect(throws: RemoteImageURLRejection.insecureScheme) {
            try policy.validatedURL(from: rawValue)
        }
    }

    @Test(arguments: [
        "https://user@cdn.shopify.com/item.jpg",
        "https://user:password@cdn.shopify.com/item.jpg"
    ])
    func rejectsEmbeddedCredentials(_ rawValue: String) {
        #expect(throws: RemoteImageURLRejection.credentials) {
            try policy.validatedURL(from: rawValue)
        }
    }

    @Test func rejectsAlternatePortsAndFragments() {
        #expect(throws: RemoteImageURLRejection.explicitPort) {
            try policy.validatedURL(from: "https://cdn.shopify.com:443/item.jpg")
        }
        #expect(throws: RemoteImageURLRejection.fragment) {
            try policy.validatedURL(from: "https://cdn.shopify.com/item.jpg#fragment")
        }
    }

    @Test(arguments: [
        "https://localhost/item.jpg",
        "https://images.local/item.jpg",
        "https://host.internal/item.jpg",
        "https://127.0.0.1/item.jpg",
        "https://127.1/item.jpg",
        "https://2130706433/item.jpg",
        "https://0x7f000001/item.jpg",
        "https://[::1]/item.jpg"
    ])
    func rejectsLocalAndAddressLiteralHosts(_ rawValue: String) {
        #expect(throws: RemoteImageURLRejection.localOrAddressLiteral) {
            try RemoteImagePolicy(allowedHostSuffixes: [
                "localhost", "images.local", "host.internal", "127.0.0.1",
                "127.1", "2130706433", "0x7f000001", "::1"
            ]).validatedURL(from: rawValue)
        }
    }

    @Test(arguments: [
        "https://evil.net/item.jpg",
        "https://cdn.shopify.com.evil.net/item.jpg",
        "https://shopify.com/item.jpg"
    ])
    func rejectsUnreviewedOrDeceptiveHosts(_ rawValue: String) {
        #expect(throws: RemoteImageURLRejection.unapprovedHost) {
            try policy.validatedURL(from: rawValue)
        }
    }

    @Test func rejectsInternationalizedHostLookalikes() {
        #expect(throws: RemoteImageURLRejection.invalidHost) {
            try policy.validatedURL(from: "https://xn--shopify-9za.net/item.jpg")
        }
    }

    @Test func rejectsMalformedWhitespaceControlsAndOversizedURLs() {
        #expect(throws: RemoteImageURLRejection.malformed) {
            try policy.validatedURL(from: "")
        }
        #expect(throws: RemoteImageURLRejection.malformed) {
            try policy.validatedURL(from: " https://cdn.shopify.com/item.jpg")
        }
        #expect(throws: RemoteImageURLRejection.malformed) {
            try policy.validatedURL(from: "https://cdn.shopify.com/item\n.jpg")
        }
        #expect(throws: RemoteImageURLRejection.tooLong) {
            try RemoteImagePolicy(
                allowedHostSuffixes: ["cdn.shopify.com"],
                maximumURLLength: 40
            ).validatedURL(from: "https://cdn.shopify.com/this-path-is-too-long.jpg")
        }
    }

    @Test(arguments: [
        "https:///item.jpg",
        "https://cdn.shopify.com./item.jpg",
        "https://cdn..shopify.com/item.jpg",
        "https://-cdn.shopify.com/item.jpg",
        "https://cdn-.shopify.com/item.jpg"
    ])
    func rejectsMalformedDNSHosts(_ rawValue: String) {
        #expect(throws: RemoteImageURLRejection.invalidHost) {
            try policy.validatedURL(from: rawValue)
        }
    }

    @Test func productionPolicyContainsOnlyDocumentedReviewedHosts() {
        #expect(RemoteImagePolicy.production.allowedHostSuffixes == [
            "assets.adidas.com",
            "cdn.shopify.com",
            "image.uniqlo.com",
            "images.asos-media.com",
            "images.ctfassets.net",
            "lp2.hm.com",
            "static.nike.com",
            "static.zara.net"
        ])
    }
}

@Suite("Remote image resource limits")
struct RemoteImageLimitTests {
    @Test func productionCeilingsStayConservative() {
        let limits = RemoteImageLimits.production
        #expect(limits.maximumDownloadBytes == 5 * 1_024 * 1_024)
        #expect(limits.maximumSourceDimension == 12_000)
        #expect(limits.maximumSourcePixels == 40_000_000)
        #expect(limits.decodedThumbnailDimension == 1_200)
        #expect(limits.cacheItemLimit == 48)
        #expect(limits.cacheCostLimitBytes == 32 * 1_024 * 1_024)
    }

    @Test func byteAndPixelLimitsAreInclusiveAndOverflowSafe() {
        let limits = RemoteImageLimits(
            maximumDownloadBytes: 100,
            maximumSourceDimension: 1_000,
            maximumSourcePixels: 500_000,
            decodedThumbnailDimension: 300,
            cacheItemLimit: 2,
            cacheCostLimitBytes: 1_024
        )

        #expect(limits.acceptsDownload(byteCount: 100))
        #expect(!limits.acceptsDownload(byteCount: 101))
        #expect(!limits.acceptsDownload(byteCount: -1))
        #expect(limits.acceptsSource(width: 1_000, height: 500))
        #expect(!limits.acceptsSource(width: 1_001, height: 1))
        #expect(!limits.acceptsSource(width: 1_000, height: 501))
        #expect(!limits.acceptsSource(width: .max, height: .max))
        #expect(!limits.acceptsSource(width: 0, height: 10))
    }

    @Test func allowsOnlySupportedStillImageMIMETypes() {
        let limits = RemoteImageLimits.production
        #expect(limits.acceptsMIMEType("image/jpeg"))
        #expect(limits.acceptsMIMEType("IMAGE/PNG"))
        #expect(limits.acceptsMIMEType("image/webp"))
        #expect(!limits.acceptsMIMEType("image/gif"))
        #expect(!limits.acceptsMIMEType("image/svg+xml"))
        #expect(!limits.acceptsMIMEType("text/html"))
        #expect(!limits.acceptsMIMEType(nil))
    }

    @Test func streamingBufferStopsBeforeExceedingTheDownloadCeiling() throws {
        var buffer = BoundedRemoteImageBuffer(maximumByteCount: 3, expectedByteCount: 10)
        try buffer.append(0x01)
        try buffer.append(0x02)
        try buffer.append(0x03)

        #expect(buffer.data == Data([0x01, 0x02, 0x03]))
        #expect(throws: RemoteImageLoadError.downloadTooLarge) {
            try buffer.append(0x04)
        }
        #expect(buffer.data == Data([0x01, 0x02, 0x03]))
    }

    @Test func responseValidationRejectsNonHTTPStatusMIMEAndDeclaredOversize() throws {
        let url = URL(string: "https://cdn.shopify.com/item.jpg")!
        let limits = RemoteImageLimits(maximumDownloadBytes: 100)

        #expect(throws: RemoteImageLoadError.invalidResponse) {
            try RemoteImageResponseValidator.validate(
                URLResponse(
                    url: url,
                    mimeType: "image/jpeg",
                    expectedContentLength: 10,
                    textEncodingName: nil
                ),
                limits: limits
            )
        }
        #expect(throws: RemoteImageLoadError.unsuccessfulStatus(302)) {
            try RemoteImageResponseValidator.validate(
                Self.response(url: url, status: 302, mime: "image/jpeg", length: "10"),
                limits: limits
            )
        }
        #expect(throws: RemoteImageLoadError.unsupportedContentType) {
            try RemoteImageResponseValidator.validate(
                Self.response(url: url, status: 200, mime: "text/html", length: "10"),
                limits: limits
            )
        }
        #expect(throws: RemoteImageLoadError.downloadTooLarge) {
            try RemoteImageResponseValidator.validate(
                Self.response(url: url, status: 200, mime: "image/jpeg", length: "101"),
                limits: limits
            )
        }
        try RemoteImageResponseValidator.validate(
            Self.response(url: url, status: 200, mime: "image/jpeg", length: "100"),
            limits: limits
        )
    }

    @Test func decoderRejectsMalformedAndOversizedData() {
        #expect(throws: RemoteImageLoadError.invalidImage) {
            try RemoteImageDecoder.decodeThumbnail(
                data: Data("not an image".utf8),
                limits: .production
            )
        }

        #expect(throws: RemoteImageLoadError.downloadTooLarge) {
            try RemoteImageDecoder.decodeThumbnail(
                data: Data(repeating: 0, count: 11),
                limits: RemoteImageLimits(maximumDownloadBytes: 10)
            )
        }
    }

    @Test func decoderDownsamplesWithinConfiguredDimension() throws {
        let source = Self.fixtureImage()
        let data = try #require(source.pngData())
        let decoded = try RemoteImageDecoder.decodeThumbnail(
            data: data,
            limits: RemoteImageLimits(decodedThumbnailDimension: 30)
        )

        #expect(decoded.size.width <= 30)
        #expect(decoded.size.height <= 30)
    }

    @Test func decoderRejectsExcessiveSourceDimensions() throws {
        let data = try #require(Self.fixtureImage().pngData())
        #expect(throws: RemoteImageLoadError.sourceDimensionsTooLarge) {
            try RemoteImageDecoder.decodeThumbnail(
                data: data,
                limits: RemoteImageLimits(maximumSourceDimension: 100)
            )
        }
    }

    @Test func decoderRejectsMultiFrameImages() throws {
        let source = try #require(Self.fixtureImage().cgImage)
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            "com.compuserve.gif" as CFString,
            2,
            nil
        ))
        CGImageDestinationAddImage(destination, source, nil)
        CGImageDestinationAddImage(destination, source, nil)
        #expect(CGImageDestinationFinalize(destination))

        #expect(throws: RemoteImageLoadError.animatedImage) {
            try RemoteImageDecoder.decodeThumbnail(
                data: data as Data,
                limits: .production
            )
        }
    }

    private static func response(
        url: URL,
        status: Int,
        mime: String,
        length: String
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime,
                "Content-Length": length
            ]
        )!
    }

    private static func fixtureImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        }
    }
}
