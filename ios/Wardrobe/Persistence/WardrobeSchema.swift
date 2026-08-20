import SwiftData

/// Fresh-install schema for the local-only catalog candidate.
///
/// This release intentionally requires removing the previous app before
/// installation; no legacy migration types or server-account ownership fields
/// are linked into the shipped target.
enum WardrobeSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, Outfit.self, WearLog.self]
    }
}
