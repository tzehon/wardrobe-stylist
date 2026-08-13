import CryptoKit
import Foundation

enum PrivacyPreferencesStoreFailure: Error, Equatable, Sendable {
    case corruptData
    case unsupportedFormatVersion(found: Int, supported: Int)
}

/// A read never silently converts malformed state into consent. Missing state is
/// the normal first-run deny-by-default value; malformed or unsupported state is
/// explicitly unavailable so every caller can fail closed and surface diagnostics.
enum PrivacyPreferencesLoadResult: Equatable, Sendable {
    case loaded(AccountPrivacyPreferences)
    case unavailable(PrivacyPreferencesStoreFailure)
}

enum PrivacyPreferencesStoreWriteError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(found: Int, supported: Int)
    case encodingFailed
}

protocol PrivacyPreferencesStoring: Sendable {
    func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult
    func save(_ preferences: AccountPrivacyPreferences, for subjectID: PrivacySubjectID) async throws
    func remove(for subjectID: PrivacySubjectID) async
}

/// Codable, account-scoped preference storage serialized through an actor.
///
/// This type directly accesses app-only `UserDefaults`; the app-owned
/// `PrivacyInfo.xcprivacy` declares `NSPrivacyAccessedAPICategoryUserDefaults`
/// with approved reason `CA92.1` for that use.
actor UserDefaultsPrivacyPreferencesStore: PrivacyPreferencesStoring {
    static let defaultKeyPrefix = "com.tth.Wardrobe.privacy.preferences"

    private let defaults: UserDefaults
    private let keyPrefix: String

    init(keyPrefix: String = defaultKeyPrefix) {
        self.defaults = .standard
        self.keyPrefix = keyPrefix
    }

    /// Suite-name injection keeps the non-Sendable `UserDefaults` instance owned
    /// entirely by this actor while allowing isolated, deterministic test stores.
    init(suiteName: String, keyPrefix: String = defaultKeyPrefix) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create UserDefaults suite: \(suiteName)")
        }
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func load(for subjectID: PrivacySubjectID) async -> PrivacyPreferencesLoadResult {
        let key = Self.storageKey(for: subjectID, keyPrefix: keyPrefix)
        guard let data = defaults.data(forKey: key) else {
            return .loaded(.defaultDeny)
        }

        let preferences: AccountPrivacyPreferences
        do {
            preferences = try Self.makeDecoder().decode(AccountPrivacyPreferences.self, from: data)
        } catch {
            return .unavailable(.corruptData)
        }

        guard preferences.formatVersion == AccountPrivacyPreferences.currentFormatVersion else {
            return .unavailable(.unsupportedFormatVersion(
                found: preferences.formatVersion,
                supported: AccountPrivacyPreferences.currentFormatVersion
            ))
        }
        return .loaded(preferences)
    }

    func save(
        _ preferences: AccountPrivacyPreferences,
        for subjectID: PrivacySubjectID
    ) async throws {
        guard preferences.formatVersion == AccountPrivacyPreferences.currentFormatVersion else {
            throw PrivacyPreferencesStoreWriteError.unsupportedFormatVersion(
                found: preferences.formatVersion,
                supported: AccountPrivacyPreferences.currentFormatVersion
            )
        }

        let data: Data
        do {
            data = try Self.makeEncoder().encode(preferences)
        } catch {
            throw PrivacyPreferencesStoreWriteError.encodingFailed
        }
        defaults.set(data, forKey: Self.storageKey(for: subjectID, keyPrefix: keyPrefix))
    }

    func remove(for subjectID: PrivacySubjectID) async {
        defaults.removeObject(forKey: Self.storageKey(for: subjectID, keyPrefix: keyPrefix))
    }

    /// Deletes and verifies one subject without touching another account's
    /// hashed key. Used by account-scoped local-data deletion.
    func removeAndVerify(for subjectID: PrivacySubjectID) -> Bool {
        let key = Self.storageKey(for: subjectID, keyPrefix: keyPrefix)
        defaults.removeObject(forKey: key)
        return defaults.object(forKey: key) == nil
    }

    /// Deletes every app-owned privacy record, including signed-out accounts
    /// whose opaque subject ids are no longer available to the current session.
    /// Enumeration is constrained to this store's namespaced prefix.
    func removeAllAppOwnedPreferencesAndVerify() -> Bool {
        let prefix = keyPrefix + "."
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        for key in keys { defaults.removeObject(forKey: key) }
        return defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix(prefix) } == false
    }

    /// Hashing keeps externally supplied identifiers and other personal values out
    /// of UserDefaults keys while preserving deterministic per-subject isolation.
    static func storageKey(for subjectID: PrivacySubjectID, keyPrefix: String) -> String {
        let digest = SHA256.hash(data: Data(subjectID.rawValue.utf8))
        let subjectHash = digest.map { String(format: "%02x", $0) }.joined()
        return "\(keyPrefix).\(subjectHash)"
    }

#if DEBUG
    /// Actor-isolated raw storage hooks for corruption/version tests. Keeping the
    /// suite instance inside the actor avoids sharing non-Sendable UserDefaults.
    func replaceRawDataForTesting(_ data: Data?, for subjectID: PrivacySubjectID) {
        let key = Self.storageKey(for: subjectID, keyPrefix: keyPrefix)
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func hasStoredDataForTesting(for subjectID: PrivacySubjectID) -> Bool {
        defaults.data(forKey: Self.storageKey(for: subjectID, keyPrefix: keyPrefix)) != nil
    }

    func replaceUnrelatedValueForTesting(_ value: String?, key: String) {
        defaults.set(value, forKey: key)
    }

    func unrelatedValueForTesting(key: String) -> String? {
        defaults.string(forKey: key)
    }
#endif

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
