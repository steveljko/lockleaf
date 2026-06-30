import Foundation

/// Errors surfaced across module boundaries. Each module may add its own cases
/// via nested types, but this gives the app a single, user-presentable surface.
public enum AppError: Error, Sendable, Equatable {
    case keychain(String)
    case persistence(String)
    case authentication(String)
    case otpParsing(String)
    case backup(String)
    case notFound
    case vaultLocked
    case invalidInput(String)

    public var userMessage: String {
        switch self {
        case .keychain(let m): "Keychain error: \(m)"
        case .persistence(let m): "Database error: \(m)"
        case .authentication(let m): "Authentication failed: \(m)"
        case .otpParsing(let m): "Could not read code: \(m)"
        case .backup(let m): "Backup error: \(m)"
        case .notFound: "The requested item could not be found."
        case .vaultLocked: "The vault is locked."
        case .invalidInput(let m): "Invalid input: \(m)"
        }
    }
}
