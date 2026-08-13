import SwiftData

/// The exact schema that shipped before explicit SwiftData versioning was added.
///
/// Keep these model types immutable. Future model changes belong in a new
/// `WardrobeSchemaV2` namespace plus a migration stage from this version. The
/// top-level `Item`, `Outfit`, and `WearLog` names remain source-compatible via
/// type aliases in their model files.
enum WardrobeSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, Outfit.self, WearLog.self]
    }
}

/// Account-isolated schema. Optional ownership fields are intentional: rows
/// written by V1 migrate as unscoped legacy data and remain blocked until the
/// user explicitly assigns or deletes them.
enum WardrobeSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Item.self,
            Outfit.self,
            WearLog.self,
            ProcessedGmailMessage.self,
            GmailSyncState.self,
        ]
    }
}

/// Ordered history of every schema the app knows how to open.
///
/// V1 has no migration stage because it intentionally preserves the persistent
/// shape and default 1.0.0 version of the previously unversioned store.
enum WardrobeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WardrobeSchemaV1.self, WardrobeSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: WardrobeSchemaV1.self,
                toVersion: WardrobeSchemaV2.self
            ),
        ]
    }
}
