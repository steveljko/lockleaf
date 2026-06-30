import CoreModels
import DomainServices
import SwiftUI
import TOTPCore

/// Renders an entry's live TOTP code plus countdown ring. The secret is read
/// only when the time step rolls over (not every tick), and never while the
/// vault is locked — in which case dots are shown instead.
struct CodeDisplay: View {
    let entry: Entry
    var fontSize: CGFloat = 22
    var ringSize: CGFloat = 22

    @Environment(VaultService.self) private var vault
    @Environment(CodeClock.self) private var clock

    @State private var code: GeneratedCode?
    @State private var lastStep: UInt64 = .max

    var body: some View {
        HStack(spacing: 10) {
            if vault.isLocked {
                Text(String(repeating: "•", count: entry.parameters.digits))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            } else if let code {
                Text(code.grouped)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: code.value)
                if entry.parameters.kind == .totp {
                    ProgressRing(progress: liveProgress, secondsRemaining: liveRemaining, size: ringSize)
                }
            } else {
                Text(String(repeating: "•", count: entry.parameters.digits))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .onChange(of: clock.date, initial: true) { _, now in refresh(at: now) }
        .onChange(of: vault.isLocked) { _, locked in if locked { code = nil; lastStep = .max } }
    }

    private var liveRemaining: Int {
        guard let code else { return entry.parameters.period }
        return max(0, Int(ceil(code.expiresAt.timeIntervalSince(clock.date))))
    }

    private var liveProgress: Double {
        let period = Double(entry.parameters.period)
        return 1 - Double(liveRemaining) / period
    }

    private func refresh(at now: Date) {
        guard !vault.isLocked, entry.parameters.kind == .totp else {
            if !vault.isLocked, entry.parameters.kind == .hotp, code == nil {
                code = try? vault.generateCode(for: entry)
            }
            return
        }
        let step = OTPGenerator.timeStep(for: now, period: entry.parameters.period)
        if step != lastStep {
            lastStep = step
            code = try? vault.generateCode(for: entry)
        }
    }
}
