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

    // Backup
    /// When on, the app keeps an encrypted backup in the user's iCloud Drive and
    /// refreshes it automatically after changes. Requires a backup password
    /// (held in the Keychain, not here).
    public var iCloudBackupEnabled: Bool

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
        showInDock: Bool = true,
        iCloudBackupEnabled: Bool = false
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
        self.iCloudBackupEnabled = iCloudBackupEnabled
    }

    public static let `default` = AppSettings()

    // Tolerant decoding: a settings blob written by an older build won't contain
    // keys added later (e.g. `iCloudBackupEnabled`). Decoding each key
    // independently with a fallback to the default means a new field never wipes
    // the user's existing preferences.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        theme = value(.theme, d.theme)
        launchAtLogin = value(.launchAtLogin, d.launchAtLogin)
        unlockMethod = value(.unlockMethod, d.unlockMethod)
        autoLockSeconds = value(.autoLockSeconds, d.autoLockSeconds)
        lockOnSleep = value(.lockOnSleep, d.lockOnSleep)
        lockOnScreenLock = value(.lockOnScreenLock, d.lockOnScreenLock)
        lockWhenAppLosesFocus = value(.lockWhenAppLosesFocus, d.lockWhenAppLosesFocus)
        clipboardClearSeconds = value(.clipboardClearSeconds, d.clipboardClearSeconds)
        secureClipboard = value(.secureClipboard, d.secureClipboard)
        defaultGroupID = (try? c.decodeIfPresent(GroupID.self, forKey: .defaultGroupID)) ?? d.defaultGroupID
        menuBarMode = value(.menuBarMode, d.menuBarMode)
        showInDock = value(.showInDock, d.showInDock)
        iCloudBackupEnabled = value(.iCloudBackupEnabled, d.iCloudBackupEnabled)
    }
}
