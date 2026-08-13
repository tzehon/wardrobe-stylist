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

/// Review-aware schema. Existing V2 rows migrate with accepted/default catalog
/// state so an upgrade never hides or blocks a wardrobe the user already used.
/// Only imports created after this version starts in pending review.
enum WardrobeSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    typealias ProcessedGmailMessage = WardrobeSchemaV2.ProcessedGmailMessage
    typealias GmailSyncState = WardrobeSchemaV2.GmailSyncState

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
        [WardrobeSchemaV1.self, WardrobeSchemaV2.self, WardrobeSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: WardrobeSchemaV1.self,
                toVersion: WardrobeSchemaV2.self
            ),
            .lightweight(
                fromVersion: WardrobeSchemaV2.self,
                toVersion: WardrobeSchemaV3.self
            ),
        ]
    }
}
