import CoreModels
import Foundation

/// A parsed `otpauth://` URI (the de-facto interchange format produced by QR
/// codes and exports). Carries the Base32 secret string plus the descriptive
/// fields; converting to/from `Entry` happens in the domain layer.
///
/// Reference: https://github.com/google/google-authenticator/wiki/Key-Uri-Format
public struct OTPAuthURI: Sendable, Equatable {
    public var kind: OTPKind
    public var issuer: String
    public var accountName: String
    public var base32Secret: String
    public var parameters: OTPParameters

    public init(
        kind: OTPKind,
        issuer: String,
        accountName: String,
        base32Secret: String,
        parameters: OTPParameters
    ) {
        self.kind = kind
        self.issuer = issuer
        self.accountName = accountName
        self.base32Secret = base32Secret
        self.parameters = parameters
    }

    /// Parse a single `otpauth://` URI. Throws `AppError.otpParsing` on any
    /// malformed or unsupported input.
    public init(string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "otpauth"
        else {
            throw AppError.otpParsing("Not an otpauth:// URI")
        }

        guard let host = components.host?.lowercased(),
              let kind = OTPKind(rawValue: host)
        else {
            throw AppError.otpParsing("Unsupported OTP type")
        }
        self.kind = kind

        let queryItems = components.queryItems ?? []
        func query(_ name: String) -> String? {
            queryItems.first { $0.name.lowercased() == name }?.value
        }

        guard let secret = query("secret"), !secret.isEmpty else {
            throw AppError.otpParsing("Missing secret")
        }
        guard Base32.decode(secret) != nil else {
            throw AppError.otpParsing("Secret is not valid Base32")
        }
        self.base32Secret = secret

        // The label is "Issuer:Account" or just "Account"; the `issuer` query
        // parameter takes precedence when present (per the spec).
        let label = components.path.hasPrefix("/")
            ? String(components.path.dropFirst())
            : components.path
        let decodedLabel = label.removingPercentEncoding ?? label

        var parsedIssuer = ""
        var parsedAccount = decodedLabel
        if let colon = decodedLabel.firstIndex(of: ":") {
            parsedIssuer = String(decodedLabel[..<colon]).trimmingCharacters(in: .whitespaces)
            parsedAccount = String(decodedLabel[decodedLabel.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        self.issuer = query("issuer") ?? parsedIssuer
        self.accountName = parsedAccount

        var params = OTPParameters(kind: kind)
        if let algo = query("algorithm"), let parsed = OTPAlgorithm(rawValue: algo.uppercased()) {
            params.algorithm = parsed
        }
        if let digits = query("digits"), let parsed = Int(digits) {
            params.digits = parsed
        }
        if let period = query("period"), let parsed = Int(period) {
            params.period = parsed
        }
        if kind == .hotp, let counter = query("counter"), let parsed = UInt64(counter) {
            params.counter = parsed
        }
        self.parameters = params
    }

    /// Scan free-form text for every `otpauth://` link and parse each one.
    /// Tolerates one-per-line files, space-separated tokens, and surrounding
    /// noise (comment lines, blank lines) — anything that isn't an `otpauth://`
    /// token is ignored. `failures` counts tokens that looked like links but
    /// could not be parsed, so callers can report partial imports.
    public static func parseMany(from text: String) -> (parsed: [OTPAuthURI], failures: Int) {
        let tokens = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        var parsed: [OTPAuthURI] = []
        var failures = 0
        for token in tokens where token.lowercased().hasPrefix("otpauth://") {
            if let uri = try? OTPAuthURI(string: String(token)) {
                parsed.append(uri)
            } else {
                failures += 1
            }
        }
        return (parsed, failures)
    }

    /// Serialize back to a canonical `otpauth://` URI (used for QR generation).
    public func uriString() -> String {
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = kind.rawValue

        let label = issuer.isEmpty ? accountName : "\(issuer):\(accountName)"
        components.path = "/" + label

        var items = [URLQueryItem(name: "secret", value: base32Secret)]
        if !issuer.isEmpty { items.append(URLQueryItem(name: "issuer", value: issuer)) }
        items.append(URLQueryItem(name: "algorithm", value: parameters.algorithm.rawValue))
        items.append(URLQueryItem(name: "digits", value: String(parameters.digits)))
        if kind == .totp {
            items.append(URLQueryItem(name: "period", value: String(parameters.period)))
        } else {
            items.append(URLQueryItem(name: "counter", value: String(parameters.counter)))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? ""
    }
}
