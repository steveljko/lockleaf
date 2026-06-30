import CoreModels
import Foundation
import Observation

/// Drives *automatic* encrypted iCloud backups. It watches `Library.revision`
/// and, when iCloud backup is enabled and possible, writes a fresh encrypted
/// backup after a short debounce so a burst of edits results in a single upload.
///
/// All the policy lives here; the actual encryption/upload is delegated to
/// `BackupCoordinator`. Manual backups (the buttons in Settings) go straight to
/// the coordinator and report their own results — this type is only the
/// background, change-driven path.
@MainActor
@Observable
public final class BackupManager {
    /// Outcome of the most recent automatic backup attempt, for status display.
    public enum Status: Sendable, Equatable {
        case idle
        case backingUp
        case succeeded(Date)
        case failed(String)
    }

    public private(set) var status: Status = .idle

    private let library: Library
    private let vault: VaultService
    private let settings: SettingsStore
    private let coordinator: BackupCoordinator

    /// Debounce window so rapid successive edits coalesce into one upload.
    private let debounce: Duration
    private var pending: Task<Void, Never>?
    private var started = false

    public init(
        library: Library,
        vault: VaultService,
        settings: SettingsStore,
        coordinator: BackupCoordinator,
        debounce: Duration = .seconds(3)
    ) {
        self.library = library
        self.vault = vault
        self.settings = settings
        self.coordinator = coordinator
        self.debounce = debounce
    }

    /// Begin observing library changes. Safe to call once after bootstrap.
    public func start() {
        guard !started else { return }
        started = true
        observe()
    }

    /// Re-arming observation: `withObservationTracking`'s `onChange` fires once,
    /// so we resubscribe each time to keep watching for the next change.
    private func observe() {
        withObservationTracking {
            _ = library.revision
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.scheduleBackup()
                self.observe()
            }
        }
    }

    /// Whether an automatic backup can run right now.
    private var canAutoBackup: Bool {
        settings.settings.iCloudBackupEnabled
            && !vault.isLocked
            && coordinator.isICloudAvailable
            && coordinator.hasBackupPassword
    }

    private func scheduleBackup() {
        guard canAutoBackup else { return }
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.debounce)
            guard !Task.isCancelled, self.canAutoBackup else { return }
            await self.runBackup()
        }
    }

    /// Trigger a backup immediately (used when the user enables the feature so the
    /// first backup is not delayed by the debounce window).
    public func backUpNow() async {
        pending?.cancel()
        await runBackup()
    }

    private func runBackup() async {
        status = .backingUp
        do {
            try await coordinator.backUpToICloud()
            status = .succeeded(coordinator.iCloudBackupDate ?? Date())
        } catch {
            status = .failed((error as? AppError)?.userMessage ?? error.localizedDescription)
        }
    }
}
