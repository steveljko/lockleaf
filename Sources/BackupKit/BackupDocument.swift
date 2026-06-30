import CoreModels
import Foundation

/// The portable representation of a vault. Unlike `Entry`, a `BackupEntry`
/// **does** carry the Base32 secret, because a backup is useless without it.
/// This DTO therefore only ever exists in memory or inside an *encrypted*
/// envelope on disk — never written to disk in the clear by `BackupService`
/// unless the user explicitly chooses the unencrypted JSON format.
public struct BackupDocument: Codable, Sendable, Equatable {
    public var version: Int
    public var exportedAt: Date
    public var groups: [Group]
    public var tags: [Tag]
    public var entries: [BackupEntry]

    public init(
        version: Int = 1,
        exportedAt: Date = Date(),
        groups: [Group],
        tags: [Tag],
        entries: [BackupEntry]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.groups = groups
        self.tags = tags
        self.entries = entries
    }
}

public struct BackupEntry: Codable, Sendable, Equatable {
    public var id: EntryID
    public var name: String
    public var issuer: String
    public var base32Secret: String
    public var parameters: OTPParameters
    public var notes: String
    public var groupID: GroupID?
    public var tagIDs: [TagID]
    public var isFavorite: Bool
    public var isPinned: Bool

    public init(
        id: EntryID,
        name: String,
        issuer: String,
        base32Secret: String,
        parameters: OTPParameters,
        notes: String,
        groupID: GroupID?,
        tagIDs: [TagID],
        isFavorite: Bool,
        isPinned: Bool
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.base32Secret = base32Secret
        self.parameters = parameters
        self.notes = notes
        self.groupID = groupID
        self.tagIDs = tagIDs
        self.isFavorite = isFavorite
        self.isPinned = isPinned
    }
}
