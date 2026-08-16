import Foundation

/// Pure validation for receipt-supplied product image URLs.
///
/// Receipt HTML and extraction responses are untrusted input. The app only
/// requests HTTPS images from this deliberately small set of reviewed CDN
/// domains. Additions should be backed by a real retailer receipt, reviewed
/// for ownership and redirect behaviour, and covered by a focused test.
struct RemoteImagePolicy: Equatable, Sendable {
    static let production = RemoteImagePolicy(allowedHostSuffixes: [
        "assets.adidas.com",
        "cdn.shopify.com",
        "image.uniqlo.com",
        "images.asos-media.com",
        "images.ctfassets.net",
        "lp2.hm.com",
        "static.nike.com",
        "static.zara.net"
    ])

    let allowedHostSuffixes: Set<String>
    let maximumURLLength: Int

    init(allowedHostSuffixes: Set<String>, maximumURLLength: Int = 2_048) {
        self.allowedHostSuffixes = Set(allowedHostSuffixes.map { $0.lowercased() })
        self.maximumURLLength = maximumURLLength
    }

    func validatedURL(from rawValue: String) throws(RemoteImageURLRejection) -> URL {
        guard !rawValue.isEmpty else { throw .malformed }
        guard rawValue.utf8.count <= maximumURLLength else { throw .tooLong }
        guard rawValue == rawValue.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw .malformed
        }
        guard let components = URLComponents(string: rawValue),
              components.scheme?.lowercased() == "https" else {
            throw .insecureScheme
        }
        guard components.user == nil, components.password == nil else {
            throw .credentials
        }
        // A fixed HTTPS origin is easier to audit than accepting alternate
        // ports. CDN query parameters remain allowed for image transforms.
        guard components.port == nil else { throw .explicitPort }
        guard components.fragment == nil else { throw .fragment }
        guard let hostValue = components.host,
              !hostValue.isEmpty,
              !hostValue.hasSuffix("."),
              hostValue.unicodeScalars.allSatisfy({ $0.isASCII }) else {
            throw .invalidHost
        }

        let host = hostValue.lowercased()
        let unbracketedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard !Self.isLocalOrAddressLiteral(unbracketedHost) else {
            throw .localOrAddressLiteral
        }
        guard Self.isSyntacticallyValidDNSName(host) else { throw .invalidHost }
        guard allowedHostSuffixes.contains(where: {
            host == $0 || host.hasSuffix(".\($0)")
        }) else {
            throw .unapprovedHost
        }
        guard let url = components.url, url.host?.lowercased() == host else {
            throw .malformed
        }
        return url
    }

    private static func isSyntacticallyValidDNSName(_ host: String) -> Bool {
        guard host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  label.first != "-",
                  label.last != "-",
                  !label.lowercased().hasPrefix("xn--") else {
                return false
            }
            return label.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-"
            }
        }
    }

    private static func isLocalOrAddressLiteral(_ host: String) -> Bool {
        let forbiddenNames = [
            "localhost", "local", "internal", "home", "lan", "test", "invalid", "example", "onion"
        ]
        if forbiddenNames.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
            return true
        }

        // URLComponents removes IPv6 brackets. Also reject legacy IPv4 forms
        // such as 127.1, integer hosts, and hexadecimal integer hosts.
        if host.contains(":"),
           host.allSatisfy({ $0.isNumber || "abcdefABCDEF:.".contains($0) }) {
            return true
        }
        if host.hasPrefix("0x") || host.allSatisfy({ $0.isNumber || $0 == "." }) {
            return true
        }
        return false
    }
}

enum RemoteImageURLRejection: Error, Equatable, Sendable {
    case malformed
    case tooLong
    case insecureScheme
    case credentials
    case explicitPort
    case fragment
    case invalidHost
    case localOrAddressLiteral
    case unapprovedHost
}

/// Central resource ceilings for downloads, source image dimensions and the
/// in-memory decoded thumbnail cache.
struct RemoteImageLimits: Equatable, Sendable {
    static let production = RemoteImageLimits()

    let maximumDownloadBytes: Int
    let maximumSourceDimension: Int
    let maximumSourcePixels: Int
    let decodedThumbnailDimension: Int
    let cacheItemLimit: Int
    let cacheCostLimitBytes: Int

    init(
        maximumDownloadBytes: Int = 5 * 1_024 * 1_024,
        maximumSourceDimension: Int = 12_000,
        maximumSourcePixels: Int = 40_000_000,
        decodedThumbnailDimension: Int = 1_200,
        cacheItemLimit: Int = 48,
        cacheCostLimitBytes: Int = 32 * 1_024 * 1_024
    ) {
        self.maximumDownloadBytes = maximumDownloadBytes
        self.maximumSourceDimension = maximumSourceDimension
        self.maximumSourcePixels = maximumSourcePixels
        self.decodedThumbnailDimension = decodedThumbnailDimension
        self.cacheItemLimit = cacheItemLimit
        self.cacheCostLimitBytes = cacheCostLimitBytes
    }

    func acceptsDownload(byteCount: Int64) -> Bool {
        byteCount >= 0 && byteCount <= Int64(maximumDownloadBytes)
    }

    func acceptsMIMEType(_ mimeType: String?) -> Bool {
        guard let mimeType else { return false }
        return ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]
            .contains(mimeType.lowercased())
    }

    func acceptsSource(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0,
              width <= maximumSourceDimension,
              height <= maximumSourceDimension else {
            return false
        }
        return width <= maximumSourcePixels / height
    }
}
