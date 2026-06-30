import SwiftUI

/// Countdown ring shown next to each code. Turns amber, then red, as the window
/// closes — a familiar authenticator affordance.
struct ProgressRing: View {
    /// 0 = just refreshed, 1 = about to expire.
    let progress: Double
    let secondsRemaining: Int
    var size: CGFloat = 22
    var lineWidth: CGFloat = 3
    var showsLabel: Bool = true

    private var remainingFraction: Double { max(0, min(1, 1 - progress)) }

    private var tint: Color {
        switch remainingFraction {
        case ..<0.15: .red
        case ..<0.35: .orange
        default: .accentColor
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: remainingFraction)
            if showsLabel {
                Text("\(secondsRemaining)")
                    .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(secondsRemaining) seconds remaining")
    }
}
