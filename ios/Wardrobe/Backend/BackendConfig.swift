import Foundation

/// Reads the backend base URL from Info.plist, where it's populated by Xcode at
/// build time from the configuration-specific xcconfig. Authentication is
/// established at runtime with App Attest; no shared bearer is bundled.
enum BackendConfig {

    enum LoadError: Error, Equatable {
        case missingValue(key: String)
        case invalidURL(String)
    }

    /// Convenience: reads from the main bundle's Info.plist.
    static func load() throws -> URL {
        try load(infoPlist: Bundle.main.infoDictionary ?? [:])
    }

    /// Test seam — pass the dictionary directly.
    static func load(
        infoPlist: [String: Any]
    ) throws -> URL {
        let urlString = (infoPlist["BackendBaseURL"] as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !urlString.isEmpty else {
            throw LoadError.missingValue(key: "BACKEND_BASE_URL")
        }
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            throw LoadError.invalidURL(urlString)
        }
        return url
    }
}
