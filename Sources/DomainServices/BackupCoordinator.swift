import BackupKit
import CoreModels
import Foundation

/// Bridges the live `Library`/`VaultService` to the portable `BackupDocument`.
/// Exporting requires an unlocked vault (it reads every secret); importing
/// writes secrets back into the vault and metadata into the store.
@MainActor
public struct BackupCoordinator {
    private let library: Library
    private let vault: VaultService
    private let service = BackupService()

    public init(library: Library, vault: VaultService) {
        self.library = library
        self.vault = vault
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
}
