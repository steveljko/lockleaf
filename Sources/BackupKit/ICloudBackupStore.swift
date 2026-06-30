import CoreModels
import Foundation

/// Stores a single encrypted backup envelope in the app's iCloud Drive container
/// so it syncs across the user's Macs. Only ever handed AES-GCM ciphertext by
/// `BackupService` — plaintext secrets are never written here.
///
/// The store is intentionally tiny and synchronous: the payload is a few KB and
/// the only blocking call (`url(forUbiquityContainerIdentifier:)`) is cheap after
/// the first launch. Callers that derive a key beforehand (PBKDF2) should still
/// keep this off the main thread; see `BackupCoordinator`.
public struct ICloudBackupStore: Sendable {
    /// The fixed file name inside the container's `Documents` folder. Keeping it
    /// stable means a backup is overwritten in place rather than accumulating.
    public static let fileName = "Lockleaf-Backup.lockleafbackup"

    /// Resolves the directory the backup file lives in, or `nil` when iCloud is
    /// unavailable (not signed in, iCloud Drive disabled, or no entitlement).
    private let directoryProvider: @Sendable () -> URL?

    /// Production initializer. `containerIdentifier` must match the
    /// `com.apple.developer.icloud-container-identifiers` entitlement; passing
    /// `nil` uses the first configured container.
    public init(containerIdentifier: String? = "iCloud.app.lockleaf.mac") {
        directoryProvider = {
            FileManager.default
                .url(forUbiquityContainerIdentifier: containerIdentifier)?
                .appendingPathComponent("Documents", isDirectory: true)
        }
    }

    /// Test/seam initializer backing the store with an arbitrary directory so the
    /// read/write/remove paths can be exercised without a real iCloud account.
    public init(directory: URL) {
        directoryProvider = { directory }
    }

    /// Whether the iCloud container can currently be reached.
    public var isAvailable: Bool { directoryProvider() != nil }

    private func resolveDirectory() throws -> URL {
        guard let directory = directoryProvider() else {
            throw AppError.backup("iCloud Drive is not available")
        }
        return directory
    }

    private func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    /// Write (or replace) the encrypted backup, creating the container's
    /// `Documents` folder if needed.
    public func write(_ data: Data) throws {
        let directory = try resolveDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: fileURL(in: directory), options: [.atomic])
        } catch {
            throw AppError.backup("Could not write iCloud backup: \(error.localizedDescription)")
        }
    }

    /// Read the encrypted backup, or `nil` if none has been written yet.
    public func read() throws -> Data? {
        let url = fileURL(in: try resolveDirectory())
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        // Best-effort nudge to materialize the file if iCloud has only a
        // placeholder locally; harmless (and expected to fail) for a plain
        // directory, so its error is ignored.
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw AppError.backup("Could not read iCloud backup: \(error.localizedDescription)")
        }
    }

    /// The modification date of the stored backup, for "Last backed up …" status.
    public func lastModified() -> Date? {
        guard let directory = directoryProvider() else { return nil }
        let url = fileURL(in: directory)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Delete the stored backup. No-op if nothing has been written.
    public func remove() throws {
        let url = fileURL(in: try resolveDirectory())
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw AppError.backup("Could not remove iCloud backup: \(error.localizedDescription)")
        }
    }
}
