import CoreModels
import Foundation
import KeychainStore
import Observation
import TOTPCore
import VaultKit

public enum VaultState: Sendable, Equatable {
    case locked
    case unlocking
    case unlocked
}

/// The security heart of the app. Owns the lock state and is the **only** path
/// through which secrets are read. While locked, every secret-accessing method
/// throws `AppError.vaultLocked`, so no view model can accidentally compute a
/// code or copy a secret when it shouldn't.
///
/// Secrets are read from the `SecretStore` on demand, used to compute a code,
/// and the `SecretBytes` buffer is wiped immediately after — they are never
/// cached in this object.
@MainActor
@Observable
public final class VaultService {
    public private(set) var state: VaultState = .locked

    private let secretStore: SecretStore
    private let authenticator: Authenticator
    private let dateProvider: DateProvider

    public init(secretStore: SecretStore, authenticator: Authenticator, dateProvider: DateProvider) {
        self.secretStore = secretStore
        self.authenticator = authenticator
        self.dateProvider = dateProvider
    }

    public var isLocked: Bool { state != .unlocked }
    public var biometryKind: BiometryKind { authenticator.biometryKind }
    public var canAuthenticate: Bool { authenticator.canAuthenticate }

    /// Present the native authentication dialog and, on success, unlock.
    public func unlock(reason: String = "Unlock your 2FA vault") async {
        guard state != .unlocked else { return }
        state = .unlocking
        do {
            try await authenticator.authenticate(reason: reason)
            state = .unlocked
        } catch {
            state = .locked
        }
    }

    /// Lock the vault. Cheap and synchronous so it can be called from any system
    /// event (sleep, screen lock, inactivity) without delay.
    public func lock() {
        state = .locked
    }

    // MARK: - Secret-gated operations

    /// Compute the current code for an entry. Requires an unlocked vault.
    public func generateCode(for entry: Entry) throws -> GeneratedCode {
        let secret = try loadSecretBytes(for: entry)
        defer { secret.wipe() }
        return secret.withUnsafeBytes { raw in
            OTPGenerator.liveCode(
                secret: Data(raw),
                parameters: entry.parameters,
                at: dateProvider.now()
            )
        }
    }

    /// Store a new/updated secret for an entry. Allowed while unlocked.
    public func storeSecret(_ base32: String, for reference: SecretReference) throws {
        guard !isLocked else { throw AppError.vaultLocked }
        guard let data = Base32.decode(base32) else {
            throw AppError.invalidInput("Secret is not valid Base32")
        }
        let bytes = SecretBytes(data)
        defer { bytes.wipe() }
        try secretStore.save(bytes, for: reference)
    }

    public func deleteSecret(for reference: SecretReference) throws {
        try secretStore.delete(reference)
    }

    /// Expose the Base32 secret for export/QR. Requires an unlocked vault and is
    /// intentionally explicit so call sites are easy to audit.
    public func exportableSecret(for entry: Entry) throws -> String {
        let secret = try loadSecretBytes(for: entry)
        defer { secret.wipe() }
        return secret.withUnsafeBytes { Base32.encode(Data($0)) }
    }

    private func loadSecretBytes(for entry: Entry) throws -> SecretBytes {
        guard !isLocked else { throw AppError.vaultLocked }
        guard let secret = try secretStore.load(entry.secretRef) else {
            throw AppError.notFound
        }
        return secret
    }
}
