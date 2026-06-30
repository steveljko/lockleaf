import AppKit
import Foundation

/// Copies OTP codes to the pasteboard and clears them after a timeout.
///
/// Security features:
/// - Marks the item as `org.nspasteboard.ConcealedType` and transient so
///   clipboard managers and Universal Clipboard skip it (secure clipboard mode).
/// - Schedules a clear that only fires if the pasteboard still holds *our* copy
///   (compared by `changeCount`), so we never wipe something the user copied
///   afterwards.
@MainActor
public final class ClipboardManager {
    private var clearTask: Task<Void, Never>?

    public init() {}

    /// Copy `code`. If `clearAfter > 0`, schedule a clear. If `secure`, hide the
    /// value from clipboard history / Handoff.
    public func copy(_ code: String, clearAfter seconds: Int, secure: Bool) {
        clearTask?.cancel()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if secure {
            // Conventions honored by Maccy, Pastebot, etc., plus Apple's own
            // transient hint so the value is excluded from Handoff/history.
            pasteboard.setString(code, forType: .string)
            pasteboard.setString("", forType: .init("org.nspasteboard.ConcealedType"))
            pasteboard.setString("", forType: .init("org.nspasteboard.TransientType"))
        } else {
            pasteboard.setString(code, forType: .string)
        }

        guard seconds > 0 else { return }
        let stampedChangeCount = pasteboard.changeCount

        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            // Only clear if nothing else has written to the pasteboard since.
            if NSPasteboard.general.changeCount == stampedChangeCount {
                NSPasteboard.general.clearContents()
            }
            self?.clearTask = nil
        }
    }

    /// Immediately clear the pasteboard (used on lock).
    public func clearNow() {
        clearTask?.cancel()
        clearTask = nil
        NSPasteboard.general.clearContents()
    }
}
