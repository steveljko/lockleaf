import CoreModels
import Foundation

/// A thread-safe, non-persistent `SecretStore` for unit tests and SwiftUI
/// previews. Never use in production — it keeps secrets in process memory only.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: [UInt8]] = [:]

    public init() {}

    public func save(_ secret: SecretBytes, for reference: SecretReference) throws {
        let bytes = secret.withUnsafeBytes { Array($0) }
        lock.withLock { storage[reference.account] = bytes }
    }

    public func load(_ reference: SecretReference) throws -> SecretBytes? {
        lock.withLock {
            guard let bytes = storage[reference.account] else { return nil }
            return SecretBytes(bytes)
        }
    }

    public func delete(_ reference: SecretReference) throws {
        lock.withLock { _ = storage.removeValue(forKey: reference.account) }
    }

    public func exists(_ reference: SecretReference) -> Bool {
        lock.withLock { storage[reference.account] != nil }
    }
}
