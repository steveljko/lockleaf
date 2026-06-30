import Foundation

/// A user-defined grouping for entries (Personal, Work, Finance, …).
/// Supports nesting via `parentID`; the UI may keep the tree shallow.
public struct Group: Identifiable, Codable, Sendable, Hashable {
    public let id: GroupID
    public var name: String
    public var avatar: Avatar
    public var color: AccentColor
    /// Parent group for nesting; `nil` means a top-level group.
    public var parentID: GroupID?
    /// Manual ordering position among siblings (drag & drop).
    public var sortOrder: Int
    public var isCollapsed: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: GroupID = GroupID(),
        name: String,
        avatar: Avatar = .symbol(name: "folder"),
        color: AccentColor = .default,
        parentID: GroupID? = nil,
        sortOrder: Int = 0,
        isCollapsed: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.color = color
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
