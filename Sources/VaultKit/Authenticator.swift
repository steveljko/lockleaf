import CoreModels
import Foundation
import LocalAuthentication

/// What kind of biometry the current Mac offers, for tailoring UI copy.
public enum BiometryKind: Sendable {
    case none, touchID, opticID, faceID
}

/// Abstraction over LocalAuthentication so the vault logic can be unit-tested
/// with a stub that returns success/failure deterministically.
public protocol Authenticator: Sendable {
    var biometryKind: BiometryKind { get }
    /// Whether any usable policy (biometrics or device password) is available.
    var canAuthenticate: Bool { get }
    /// Present the native authentication UI. Throws `AppError.authentication`
    /// on cancel/failure.
    func authenticate(reason: String) async throws
}

/// Production `Authenticator` backed by `LAContext`.
///
/// A fresh `LAContext` is created per call: an `LAContext` caches a successful
/// evaluation for the lifetime of the object, which would defeat re-locking, so
/// we never reuse one across unlock attempts.
public struct LocalAuthenticator: Authenticator {
    public init() {}

    private func makeContext() -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password…"
        return context
    }

    public var biometryKind: BiometryKind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        default: return .none
        }
    }

    public var canAuthenticate: Bool {
        makeContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    public func authenticate(reason: String) async throws {
        let context = makeContext()
        do {
            // `.deviceOwnerAuthentication` = biometrics (incl. Apple Watch) with
            // automatic fallback to the macOS account password.
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            guard success else {
                throw AppError.authentication("Authentication was not successful")
            }
        } catch let error as LAError {
            throw AppError.authentication(error.localizedDescription)
        }
    }
}
