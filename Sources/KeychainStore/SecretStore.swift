import CoreModels
import Foundation

/// Abstraction over secret persistence so the domain layer can be tested with
/// an in-memory double and the app can swap in the Keychain-backed
/// implementation. Secrets are passed as `SecretBytes` to keep their lifetime
/// controlled and to enable explicit wiping.
public protocol SecretStore: Sendable {
    /// Store (or replace) the secret for a reference.
    func save(_ secret: SecretBytes, for reference: SecretReference) throws
    /// Fetch the secret, requiring user presence/biometrics if the store is
    /// configured for it. Returns `nil` if no item exists.
    func load(_ reference: SecretReference) throws -> SecretBytes?
    /// Remove the secret.
    func delete(_ reference: SecretReference) throws
    /// True if a secret exists without decrypting it.
    func exists(_ reference: SecretReference) -> Bool
}
