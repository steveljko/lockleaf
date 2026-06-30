import Foundation

/// A 2FA account. **Contains no secret.** The secret lives in the Keychain and
/// is located via `secretRef`. Everything here is non-sensitive metadata that
/// is safe to persist in SQLite and show in the UI while locked (except codes,
/// which require the secret to compute).
public struct Entry: Identifiable, Codable, Sendable, Hashable {
    public let id: EntryID

    /// The account label, e.g. "alice@example.com".
    public var name: String
    /// The service provider, e.g. "GitHub".
    public var issuer: String
    /// Opaque handle to the Keychain item that stores the secret. Never the
    /// secret itself.
    public var secretRef: SecretReference
    public var parameters: OTPParameters

    public var avatar: Avatar
    public var color: AccentColor
    public var notes: String
    public var tagIDs: [TagID]
    public var groupID: GroupID?

    public var isFavorite: Bool
    public var isPinned: Bool

    public var createdAt: Date
    public var modifiedAt: Date
    /// Manual ordering within a group.
    public var sortOrder: Int

    public init(
        id: EntryID = EntryID(),
        name: String,
        issuer: String,
        secretRef: SecretReference,
        parameters: OTPParameters = .standard,
        avatar: Avatar = .default,
        color: AccentColor = .default,
        notes: String = "",
        tagIDs: [TagID] = [],
        groupID: GroupID? = nil,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.secretRef = secretRef
        self.parameters = parameters
        self.avatar = avatar
        self.color = color
        self.notes = notes
        self.tagIDs = tagIDs
        self.groupID = groupID
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sortOrder = sortOrder
    }

    /// Text used for fuzzy search. Excludes secret material by construction.
    public var searchableText: String {
        "\(name) \(issuer) \(notes)"
    }
}

/// A stable, non-secret identifier for a Keychain item. We use the entry's UUID
/// string as the Keychain `account`, which keeps the mapping deterministic and
/// avoids storing any lookup data in plaintext SQLite beyond this opaque token.
public struct SecretReference: Codable, Sendable, Hashable {
    public let account: String

    public init(account: String) {
        self.account = account
    }

    public init(for entryID: EntryID) {
        self.account = entryID.rawValue.uuidString
    }
}
