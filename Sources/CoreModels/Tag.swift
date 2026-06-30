import Foundation

/// A lightweight, cross-group label for entries.
public struct Tag: Identifiable, Codable, Sendable, Hashable {
    public let id: TagID
    public var name: String
    public var color: AccentColor

    public init(id: TagID = TagID(), name: String, color: AccentColor = .gray) {
        self.id = id
        self.name = name
        self.color = color
    }
}
