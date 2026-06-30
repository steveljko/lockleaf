import CoreModels
import Foundation

/// A computed OTP plus the timing context the UI needs to render a countdown.
public struct GeneratedCode: Sendable, Equatable {
    public let value: String
    /// Seconds remaining in the current time step (TOTP only).
    public let secondsRemaining: Int
    /// Fraction (0...1) of the current period already elapsed — drives the ring.
    public let progress: Double
    /// When this code stops being valid.
    public let expiresAt: Date

    /// Format the code into readable groups, e.g. "123 456".
    public var grouped: String {
        let chars = Array(value)
        guard chars.count > 4 else { return value }
        let mid = chars.count / 2
        return String(chars[..<mid]) + " " + String(chars[mid...])
    }
}

extension OTPGenerator {
    /// Produce a `GeneratedCode` for an entry's parameters at a given time.
    public static func liveCode(
        secret: Data,
        parameters: OTPParameters,
        at date: Date = Date()
    ) -> GeneratedCode {
        switch parameters.kind {
        case .hotp:
            let value = generate(
                secret: secret,
                counter: parameters.counter,
                algorithm: parameters.algorithm,
                digits: parameters.digits
            )
            return GeneratedCode(value: value, secondsRemaining: 0, progress: 0, expiresAt: .distantFuture)

        case .totp:
            let period = Double(parameters.period)
            let elapsed = date.timeIntervalSince1970
            let stepProgress = elapsed.truncatingRemainder(dividingBy: period)
            let remaining = period - stepProgress
            let value = generate(
                secret: secret,
                at: date,
                algorithm: parameters.algorithm,
                digits: parameters.digits,
                period: parameters.period
            )
            return GeneratedCode(
                value: value,
                secondsRemaining: Int(ceil(remaining)),
                progress: stepProgress / period,
                expiresAt: date.addingTimeInterval(remaining)
            )
        }
    }
}
