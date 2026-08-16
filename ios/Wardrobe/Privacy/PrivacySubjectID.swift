import Foundation

/// Opaque namespace used to isolate privacy preferences for one local subject.
///
/// `.deviceLocal` supports today's single-user app without coupling this privacy
/// layer to an authentication provider. A future account layer can supply a stable
/// identifier through `external(_:)`; callers must not use an email address or
/// another user-facing value.
struct PrivacySubjectID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let deviceLocal = Self(rawValue: "device-local:v1")

    static func external(_ stableID: String) -> Self {
        Self(rawValue: "external:v1:\(stableID)")
    }

    /// External account subjects use a stable provider identifier. This is
    /// false for the device-local namespace and for malformed persisted input.
    var isExternal: Bool {
        rawValue.hasPrefix("external:v1:") && rawValue.count > "external:v1:".count
    }
}
