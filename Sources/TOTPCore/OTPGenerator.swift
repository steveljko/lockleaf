import CryptoKit
import CoreModels
import Foundation

/// Stateless generator implementing HOTP (RFC 4226) and TOTP (RFC 6238).
///
/// The generator takes the raw secret bytes; it never touches the Keychain or
/// Base32 — those concerns live in their own layers. This keeps it pure and
/// exhaustively testable against the RFC test vectors.
public enum OTPGenerator {

    /// Generate a code for an explicit counter (HOTP core, RFC 4226 §5.3).
    public static func generate(
        secret: Data,
        counter: UInt64,
        algorithm: OTPAlgorithm,
        digits: Int
    ) -> String {
        var bigEndianCounter = counter.bigEndian
        let counterData = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }

        let hmac = hmac(key: secret, message: counterData, algorithm: algorithm)

        // Dynamic truncation (RFC 4226 §5.3).
        let offset = Int(hmac[hmac.count - 1] & 0x0F)
        let binary =
            (UInt32(hmac[offset] & 0x7F) << 24) |
            (UInt32(hmac[offset + 1]) << 16) |
            (UInt32(hmac[offset + 2]) << 8) |
            UInt32(hmac[offset + 3])

        let modulus = UInt32(pow(10.0, Double(digits)))
        let otp = binary % modulus
        return String(format: "%0\(digits)d", otp)
    }

    /// Generate a TOTP code for a point in time (RFC 6238 §4).
    public static func generate(
        secret: Data,
        at date: Date,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int,
        epoch: Date = Date(timeIntervalSince1970: 0)
    ) -> String {
        let counter = timeStep(for: date, period: period, epoch: epoch)
        return generate(secret: secret, counter: counter, algorithm: algorithm, digits: digits)
    }

    /// The current TOTP time step (number of `period`s since `epoch`).
    public static func timeStep(for date: Date, period: Int, epoch: Date = Date(timeIntervalSince1970: 0)) -> UInt64 {
        let elapsed = date.timeIntervalSince(epoch)
        return UInt64(floor(elapsed / Double(period)))
    }

    // MARK: - Private

    private static func hmac(key: Data, message: Data, algorithm: OTPAlgorithm) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch algorithm {
        case .sha1:
            var mac = HMAC<Insecure.SHA1>(key: symmetricKey)
            mac.update(data: message)
            return Data(mac.finalize())
        case .sha256:
            var mac = HMAC<SHA256>(key: symmetricKey)
            mac.update(data: message)
            return Data(mac.finalize())
        case .sha512:
            var mac = HMAC<SHA512>(key: symmetricKey)
            mac.update(data: message)
            return Data(mac.finalize())
        }
    }
}
