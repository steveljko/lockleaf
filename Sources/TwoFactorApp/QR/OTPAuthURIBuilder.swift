import CoreModels
import Foundation
import TOTPCore

/// Builds a canonical `otpauth://` URI from an `Entry` plus its (just-decrypted)
/// Base32 secret, for QR rendering and export.
enum OTPAuthURIBuilder {
    static func make(entry: Entry, base32Secret: String) -> String {
        OTPAuthURI(
            kind: entry.parameters.kind,
            issuer: entry.issuer,
            accountName: entry.name,
            base32Secret: base32Secret,
            parameters: entry.parameters
        ).uriString()
    }
}
