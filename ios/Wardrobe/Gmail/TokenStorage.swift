import Foundation
import Security

/// Stores Gmail OAuth tokens (and a backend device token) in the iOS Keychain.
///
/// Items are written as `kSecClassGenericPassword` with accessibility
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — they're readable only while the device
/// is unlocked, never sync to iCloud, and never migrate in backups.
struct TokenStorage: Sendable {
    /// Service identifier — different services (or test instances) can coexist without
    /// stepping on each other.
    let service: String

    init(service: String = "wardrobe.gmail") {
        self.service = service
    }

    /// Stores a value for an account, overwriting any existing entry atomically.
    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)

        // Try to update an existing item first; fall back to add if absent.
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw TokenStorageError.osStatus(addStatus)
            }
        default:
            throw TokenStorageError.osStatus(updateStatus)
        }
    }

    /// Returns the stored value, or `nil` if no entry exists for the account.
    func get(_ account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw TokenStorageError.unexpectedData
            }
            return value
        default:
            throw TokenStorageError.osStatus(status)
        }
    }

    /// Removes the entry for an account if present; succeeds silently if it doesn't exist.
    func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStorageError.osStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum TokenStorageError: Error, Equatable {
    case osStatus(OSStatus)
    case unexpectedData
}
