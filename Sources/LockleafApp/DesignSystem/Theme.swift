import CoreModels
import SwiftUI

/// Maps the model's palette to SwiftUI colors and centralizes spacing/metrics so
/// the UI stays visually consistent — the kind of small design system that makes
/// an app feel cohesive rather than assembled.
extension AccentColor {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .gray: .gray
        }
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum Metrics {
    static let cornerRadius: CGFloat = 10
    static let avatarSmall: CGFloat = 28
    static let avatarMedium: CGFloat = 40
    static let avatarLarge: CGFloat = 64
    static let rowSpacing: CGFloat = 12
}
