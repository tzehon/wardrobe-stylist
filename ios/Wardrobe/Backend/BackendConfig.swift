import Foundation

/// Reads the backend base URL + device token from Info.plist, where they're
/// populated by Xcode at build time from `Config.xcconfig` → `Secrets.xcconfig`.
/// Fail-closed: empty / missing values throw rather than silently degrade.
enum BackendConfig {

    enum LoadError: Error, Equatable {
        case missingValue(key: String)
        case invalidURL(String)
    }

    /// Convenience: reads from the main bundle's Info.plist.
    static func load() throws -> (baseURL: URL, deviceToken: String) {
        try load(infoPlist: Bundle.main.infoDictionary ?? [:])
    }

    /// Test seam — pass the dictionary directly.
    static func load(
        infoPlist: [String: Any]
    ) throws -> (baseURL: URL, deviceToken: String) {
        let urlString = (infoPlist["BackendBaseURL"] as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !urlString.isEmpty else {
            throw LoadError.missingValue(key: "BACKEND_BASE_URL")
        }
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw LoadError.invalidURL(urlString)
        }
        let token = (infoPlist["BackendDeviceToken"] as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !token.isEmpty else {
            throw LoadError.missingValue(key: "BACKEND_DEVICE_TOKEN")
        }
        return (url, token)
    }
}
