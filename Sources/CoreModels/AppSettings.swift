import Foundation

public enum AppTheme: String, Codable, Sendable, CaseIterable {
    case system, light, dark
}

/// How the vault unlocks. Stored in plaintext settings (non-sensitive choice).
public enum UnlockMethod: String, Codable, Sendable, CaseIterable {
    /// Touch ID / Apple Watch / device password via LocalAuthentication.
    case biometricsOrPassword
    /// A separate master password verified against a Secure-Enclave-derived key.
    case masterPassword
}

/// All user-configurable preferences. No secrets. Persisted as JSON in the
/// settings table (or UserDefaults via the repository) so it is trivially
/// serializable and testable.
public struct AppSettings: Codable, Sendable, Equatable {
    public var theme: AppTheme
    public var launchAtLogin: Bool

    // Locking
    public var unlockMethod: UnlockMethod
    /// Seconds of inactivity before auto-lock. `0` disables inactivity lock.
    public var autoLockSeconds: Int
    public var lockOnSleep: Bool
    public var lockOnScreenLock: Bool
    public var lockWhenAppLosesFocus: Bool

    // Clipboard
    /// Seconds before the clipboard is cleared after a copy. `0` disables.
    public var clipboardClearSeconds: Int
    /// Mark copied codes as transient/concealed so they are excluded from
    /// clipboard history and Universal Clipboard.
    public var secureClipboard: Bool

    // Behavior
    public var defaultGroupID: GroupID?
    public var menuBarMode: Bool
    public var showInDock: Bool

    public init(
        theme: AppTheme = .system,
        launchAtLogin: Bool = false,
        unlockMethod: UnlockMethod = .biometricsOrPassword,
        autoLockSeconds: Int = 300,
        lockOnSleep: Bool = true,
        lockOnScreenLock: Bool = true,
        lockWhenAppLosesFocus: Bool = false,
        clipboardClearSeconds: Int = 20,
        secureClipboard: Bool = true,
        defaultGroupID: GroupID? = nil,
        menuBarMode: Bool = true,
        showInDock: Bool = true
    ) {
        self.theme = theme
        self.launchAtLogin = launchAtLogin
        self.unlockMethod = unlockMethod
        self.autoLockSeconds = autoLockSeconds
        self.lockOnSleep = lockOnSleep
        self.lockOnScreenLock = lockOnScreenLock
        self.lockWhenAppLosesFocus = lockWhenAppLosesFocus
        self.clipboardClearSeconds = clipboardClearSeconds
        self.secureClipboard = secureClipboard
        self.defaultGroupID = defaultGroupID
        self.menuBarMode = menuBarMode
        self.showInDock = showInDock
    }

    public static let `default` = AppSettings()
}
