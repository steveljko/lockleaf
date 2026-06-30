import AppKit
import SwiftUI

extension View {
    /// Show the macOS pointing-hand cursor while hovering, signalling that an
    /// element is clickable — the affordance native controls give for free but
    /// custom tappable views don't.
    func pointerCursor(_ active: Bool = true) -> some View {
        onHover { hovering in
            guard active else { return }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// A reusable "tappable surface" background that highlights on hover, used to
/// make custom row controls read as buttons.
struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 7
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = 7) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }
}
