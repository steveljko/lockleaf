import BackupKit
import CoreModels
import Foundation
import KeychainStore

/// Bridges the live `Library`/`VaultService` to the portable `BackupDocument`.
/// Exporting requires an unlocked vault (it reads every secret); importing
/// writes secrets back into the vault and metadata into the store.
@MainActor
public struct BackupCoordinator {
    private let library: Library
    private let vault: VaultService
    private let secretStore: SecretStore
    private let iCloud: ICloudBackupStore
    private let service = BackupService()

    /// Keychain account for the password used to encrypt automatic/iCloud
    /// backups. Stored separately from OTP secrets and never written to disk in
    /// the clear, exactly like every other secret in this app.
    private static let backupPasswordRef = SecretReference(account: "app.lockleaf.backup-password")

    public init(
        library: Library,
        vault: VaultService,
        secretStore: SecretStore,
        iCloud: ICloudBackupStore = ICloudBackupStore()
    ) {
        self.library = library
        self.vault = vault
        self.secretStore = secretStore
        self.iCloud = iCloud
    }

    /// Assemble a `BackupDocument` by reading each entry's secret from the vault.
    public func makeDocument() throws -> BackupDocument {
        let backupEntries: [BackupEntry] = try library.entries.map { entry in
            let secret = try vault.exportableSecret(for: entry)
            return BackupEntry(
                id: entry.id,
                name: entry.name,
                issuer: entry.issuer,
                base32Secret: secret,
                parameters: entry.parameters,
                notes: entry.notes,
                groupID: entry.groupID,
                tagIDs: entry.tagIDs,
                isFavorite: entry.isFavorite,
                isPinned: entry.isPinned
            )
        }
        return BackupDocument(groups: library.groups, tags: library.tags, entries: backupEntries)
    }

    public func exportEncrypted(password: String) throws -> Data {
        try service.exportEncrypted(makeDocument(), password: password)
    }

    /// Plain export. Callers MUST warn the user that secrets are unprotected.
    public func exportPlain() throws -> Data {
        try service.exportPlain(makeDocument())
    }

    public func isEncrypted(_ data: Data) -> Bool { service.isEncrypted(data) }

    /// Restore a backup, recreating groups, tags, and entries (with secrets).
    /// Existing items with the same IDs are overwritten.
    public func restore(_ data: Data, password: String?) throws {
        let document: BackupDocument
        if service.isEncrypted(data) {
            guard let password, !password.isEmpty else {
                throw AppError.backup("This backup is encrypted; a password is required")
            }
            document = try service.importEncrypted(data, password: password)
        } else {
            document = try service.importPlain(data)
        }

        for group in document.groups { library.adoptGroup(group) }
        for tag in document.tags { library.adoptTag(tag) }
        for backupEntry in document.entries {
            let reference = SecretReference(for: backupEntry.id)
            try vault.storeSecret(backupEntry.base32Secret, for: reference)
            let entry = Entry(
                id: backupEntry.id,
                name: backupEntry.name,
                issuer: backupEntry.issuer,
                secretRef: reference,
                parameters: backupEntry.parameters,
                notes: backupEntry.notes,
                tagIDs: backupEntry.tagIDs,
                groupID: backupEntry.groupID,
                isFavorite: backupEntry.isFavorite,
                isPinned: backupEntry.isPinned
            )
            library.adoptEntry(entry)
        }
    }

    // MARK: - iCloud backup

    /// Whether the iCloud Drive container is reachable right now.
    public var isICloudAvailable: Bool { iCloud.isAvailable }

    /// Whether a backup password has been set (required for automatic/iCloud
    /// backups, which run without prompting).
    public var hasBackupPassword: Bool { secretStore.exists(Self.backupPasswordRef) }

    /// Modification date of the current iCloud backup, for status display.
    public var iCloudBackupDate: Date? { iCloud.lastModified() }

    /// Store (or replace) the password used for automatic/iCloud backups.
    public func setBackupPassword(_ password: String) throws {
        guard !password.isEmpty else { throw AppError.backup("A password is required") }
        let bytes = SecretBytes(Data(password.utf8))
        defer { bytes.wipe() }
        try secretStore.save(bytes, for: Self.backupPasswordRef)
    }

    /// Forget the stored backup password. Disabling iCloud backup calls this.
    public func clearBackupPassword() throws {
        try secretStore.delete(Self.backupPasswordRef)
    }

    private func storedBackupPassword() throws -> String {
        guard let bytes = try secretStore.load(Self.backupPasswordRef) else {
            throw AppError.backup("No backup password is set")
        }
        defer { bytes.wipe() }
        return bytes.withUnsafeBytes { String(decoding: Data($0), as: UTF8.self) }
    }

    /// Write an encrypted backup to iCloud using the stored password. The vault
    /// must be unlocked (the document is assembled from live secrets). The
    /// expensive PBKDF2 + AES work runs off the main actor so the UI never stalls.
    public func backUpToICloud() async throws {
        guard iCloud.isAvailable else { throw AppError.backup("iCloud Drive is not available") }
        let document = try makeDocument()
        let password = try storedBackupPassword()
        let service = self.service
        let iCloud = self.iCloud
        try await Task.detached(priority: .utility) {
            let data = try service.exportEncrypted(document, password: password)
            try iCloud.write(data)
        }.value
    }

    /// Restore from the iCloud backup. The password is supplied by the user (we
    /// do not rely on the stored one, so a backup made on another device with a
    /// different password can still be restored).
    public func restoreFromICloud(password: String) throws {
        guard let data = try iCloud.read() else {
            throw AppError.backup("No iCloud backup was found")
        }
        try restore(data, password: password)
    }

    /// Remove the backup file from iCloud (e.g. when turning the feature off).
    public func removeICloudBackup() throws {
        try iCloud.remove()
    }
}
