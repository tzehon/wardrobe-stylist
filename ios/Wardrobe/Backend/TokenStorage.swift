import Foundation
import Security

/// Stores small credentials and identifiers in the iOS Keychain.
///
/// Items are generic-password records with a caller-selected device-only
/// accessibility policy, so they neither sync through iCloud nor migrate in a
/// backup.
struct TokenStorage: Sendable {
    enum Accessibility: Sendable {
        case whenUnlockedThisDeviceOnly
        case afterFirstUnlockThisDeviceOnly

        fileprivate var securityValue: CFString {
            switch self {
            case .whenUnlockedThisDeviceOnly:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlockThisDeviceOnly:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
        }
    }

    let service: String
    let accessibility: Accessibility

    init(
        service: String = "wardrobe.secure-storage",
        accessibility: Accessibility = .whenUnlockedThisDeviceOnly
    ) {
        self.service = service
        self.accessibility = accessibility
    }

    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = accessibility.securityValue
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw TokenStorageError.osStatus(addStatus)
            }
        default:
            throw TokenStorageError.osStatus(updateStatus)
        }
    }

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
