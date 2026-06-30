import Foundation

/// Indirection over "now" so time-dependent logic (code generation, auto-lock)
/// is deterministic in tests.
public protocol DateProvider: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}
    public func now() -> Date { Date() }
}
