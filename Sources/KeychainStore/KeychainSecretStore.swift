import CoreModels
import Foundation
import Security

/// `SecretStore` backed by Keychain Services.
///
/// Design choices that maximize security:
/// - Class `kSecClassGenericPassword` scoped to a fixed service string.
/// - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` so secrets are never in an
///   iCloud Keychain backup and are only readable while the Mac is unlocked.
/// - Optional `SecAccessControl` requiring `.userPresence` (Touch ID / password)
///   on every read, so even a running app cannot silently exfiltrate secrets.
public struct KeychainSecretStore: SecretStore {
    private let service: String
    private let accessGroup: String?
    private let requireUserPresence: Bool

    public init(
        service: String = "app.lockleaf.secrets",
        accessGroup: String? = nil,
        requireUserPresence: Bool = false
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.requireUserPresence = requireUserPresence
    }

    private func baseQuery(_ reference: SecretReference) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    public func save(_ secret: SecretBytes, for reference: SecretReference) throws {
        let data = secret.unsafeData()
        defer { /* `data` is a transient copy; ARC releases it immediately. */ }

        // Delete any existing item first so we never end up with duplicates.
        SecItemDelete(baseQuery(reference) as CFDictionary)

        var attributes = baseQuery(reference)
        attributes[kSecValueData as String] = data

        if requireUserPresence {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &error
            ) else {
                throw AppError.keychain("Could not create access control")
            }
            attributes[kSecAttrAccessControl as String] = access
        } else {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychain(Self.message(for: status))
        }
    }

    public func load(_ reference: SecretReference) throws -> SecretBytes? {
        var query = baseQuery(reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            let bytes = SecretBytes(data)
            return bytes
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled, errSecAuthFailed:
            throw AppError.authentication(Self.message(for: status))
        default:
            throw AppError.keychain(Self.message(for: status))
        }
    }

    public func delete(_ reference: SecretReference) throws {
        let status = SecItemDelete(baseQuery(reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychain(Self.message(for: status))
        }
    }

    public func exists(_ reference: SecretReference) -> Bool {
        var query = baseQuery(reference)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private static func message(for status: OSStatus) -> String {
        if let str = SecCopyErrorMessageString(status, nil) as String? {
            return str
        }
        return "OSStatus \(status)"
    }
}
