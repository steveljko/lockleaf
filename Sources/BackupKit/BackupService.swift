import CoreModels
import CryptoKit
import Foundation

/// The on-disk envelope for an encrypted backup. Only non-secret KDF parameters
/// and the AES-GCM ciphertext are stored; the plaintext `BackupDocument` is
/// recoverable only with the user's password.
public struct EncryptedBackupEnvelope: Codable, Sendable, Equatable {
    public var format: String          // "lockleaf.encrypted-backup"
    public var version: Int            // envelope schema version
    public var kdf: String             // "pbkdf2-hmac-sha256"
    public var iterations: Int
    public var salt: Data              // base64 via Data's Codable
    public var nonce: Data
    public var ciphertext: Data        // AES-GCM combined (ciphertext + tag)
}

/// Imports and exports vault backups in plain or encrypted JSON.
public struct BackupService: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    public static let encryptedFormat = "lockleaf.encrypted-backup"

    public init() {
        // Default date strategy (reference-date Double) is used so timestamps
        // round-trip *exactly*; ISO-8601 would silently truncate sub-second
        // precision and break equality of restored documents.
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    // MARK: - Plain JSON (explicit, warned-about path)

    public func exportPlain(_ document: BackupDocument) throws -> Data {
        try encoder.encode(document)
    }

    public func importPlain(_ data: Data) throws -> BackupDocument {
        do {
            return try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw AppError.backup("Unreadable backup file")
        }
    }

    // MARK: - Encrypted JSON

    public func exportEncrypted(
        _ document: BackupDocument,
        password: String,
        iterations: Int = PasswordKDF.defaultIterations
    ) throws -> Data {
        guard !password.isEmpty else { throw AppError.backup("A password is required") }

        let plaintext = try encoder.encode(document)
        let salt = PasswordKDF.randomData(PasswordKDF.saltLength)
        let key = try PasswordKDF.deriveKey(password: password, salt: salt, iterations: iterations)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

        guard let combined = sealed.combined else {
            throw AppError.backup("Encryption failed")
        }
        let envelope = EncryptedBackupEnvelope(
            format: Self.encryptedFormat,
            version: 1,
            kdf: "pbkdf2-hmac-sha256",
            iterations: iterations,
            salt: salt,
            nonce: Data(nonce),
            ciphertext: combined
        )
        return try encoder.encode(envelope)
    }

    public func importEncrypted(_ data: Data, password: String) throws -> BackupDocument {
        let envelope: EncryptedBackupEnvelope
        do {
            envelope = try decoder.decode(EncryptedBackupEnvelope.self, from: data)
        } catch {
            throw AppError.backup("Not a valid encrypted backup")
        }
        guard envelope.format == Self.encryptedFormat else {
            throw AppError.backup("Unrecognized backup format")
        }

        let key = try PasswordKDF.deriveKey(password: password, salt: envelope.salt, iterations: envelope.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(box, using: key)
            return try decoder.decode(BackupDocument.self, from: plaintext)
        } catch is CryptoKitError {
            // Authentication tag mismatch — wrong password or tampered file.
            throw AppError.backup("Incorrect password or corrupted backup")
        } catch {
            throw AppError.backup("Could not read backup contents")
        }
    }

    /// Detect whether arbitrary data looks like an encrypted envelope so the UI
    /// can prompt for a password only when needed.
    public func isEncrypted(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["format"] as? String == Self.encryptedFormat
    }
}
