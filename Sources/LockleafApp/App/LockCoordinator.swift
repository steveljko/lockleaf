import AppKit
import Combine
import DomainServices
import Foundation
import VaultKit

/// Translates system and user-activity signals into vault lock commands per the
/// user's security preferences. This is where "lock on sleep / screen lock /
/// inactivity / focus loss" is actually enforced.
@MainActor
final class LockCoordinator {
    private let vault: VaultService
    private let settings: SettingsStore
    private let clipboard: ClipboardManager

    private var inactivityTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(vault: VaultService, settings: SettingsStore, clipboard: ClipboardManager) {
        self.vault = vault
        self.settings = settings
        self.clipboard = clipboard
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let app = NotificationCenter.default

        // Each observer hops to the main actor and re-checks the relevant
        // preference before locking.
        func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in handler() }
            })
        }

        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in
            guard let self, self.settings.settings.lockOnSleep else { return }
            self.lock()
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.lock() // fast user switching — always protect
        }
        // Screen lock/unlock are delivered as distributed notifications.
        observe(distributed, .init("com.apple.screenIsLocked")) { [weak self] in
            guard let self, self.settings.settings.lockOnScreenLock else { return }
            self.lock()
        }
        observe(app, NSApplication.willResignActiveNotification) { [weak self] in
            guard let self, self.settings.settings.lockWhenAppLosesFocus else { return }
            self.lock()
        }

        resetInactivityTimer()
    }

    /// Call on meaningful user interaction to defer auto-lock.
    func registerActivity() {
        resetInactivityTimer()
    }

    func lock() {
        clipboard.clearNow()
        vault.lock()
        inactivityTimer?.invalidate()
    }

    /// Restart the inactivity countdown after an unlock.
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        let seconds = settings.settings.autoLockSeconds
        guard seconds > 0, !vault.isLocked else { return }
        let timer = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.lock() }
        }
        RunLoop.main.add(timer, forMode: .common)
        inactivityTimer = timer
    }

    /// Detach all observers. The coordinator lives for the app's lifetime, so
    /// this exists mainly for completeness and testability.
    func tearDown() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()
        inactivityTimer?.invalidate()
    }
}
