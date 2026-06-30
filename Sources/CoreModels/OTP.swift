import Foundation

/// Hash algorithm used by the HMAC step of the OTP generation (RFC 6238 §1.2).
public enum OTPAlgorithm: String, Codable, Sendable, CaseIterable, Hashable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    public var displayName: String { rawValue }
}

/// One-time-password kind. The product is TOTP-first but the engine also
/// understands counter-based HOTP so that imported `otpauth://hotp` URIs work.
public enum OTPKind: String, Codable, Sendable, Hashable {
    case totp
    case hotp
}

/// The non-secret parameters that, together with the secret, fully describe how
/// to generate codes for an entry. Carries no secret material — safe to store in
/// SQLite, log, and serialize.
public struct OTPParameters: Codable, Sendable, Hashable {
    public var kind: OTPKind
    public var algorithm: OTPAlgorithm
    public var digits: Int
    /// Time step in seconds for TOTP; ignored for HOTP.
    public var period: Int
    /// Moving counter for HOTP; ignored for TOTP.
    public var counter: UInt64

    public init(
        kind: OTPKind = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0
    ) {
        self.kind = kind
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
    }

    public static let standard = OTPParameters()

    /// Validation per the practical bounds most authenticators accept.
    public var isValid: Bool {
        (6...8).contains(digits) && period >= 1 && period <= 300
    }
}
