import CommonCrypto
import CoreModels
import CryptoKit
import Foundation

/// Password-based key derivation for encrypted backups.
///
/// We use PBKDF2-HMAC-SHA256 (via CommonCrypto, the only audited PBKDF in the
/// platform) with a high iteration count and a random per-backup salt, then feed
/// the 256-bit output into AES-GCM. PBKDF2 is chosen over a bare hash because it
/// is deliberately slow, frustrating offline guessing of the backup password.
public enum PasswordKDF {
    public static let defaultIterations = 600_000
    static let keyLength = 32 // bytes -> AES-256
    static let saltLength = 16

    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: keyLength)
        let passwordBytes = Array(password.utf8)

        let status = salt.withUnsafeBytes { saltBuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes, passwordBytes.count,
                saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &derived, keyLength
            )
        }
        guard status == kCCSuccess else {
            throw AppError.backup("Key derivation failed (\(status))")
        }
        defer { derived.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        return SymmetricKey(data: Data(derived))
    }

    static func randomData(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}
