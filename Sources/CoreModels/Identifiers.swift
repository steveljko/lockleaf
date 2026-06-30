import Foundation

/// A type-safe wrapper around a UUID so that, e.g., an `EntryID` can never be
/// passed where a `GroupID` is expected. Prevents a whole class of ID mix-ups.
public struct Identifier<Subject>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

public enum EntryTag {}
public enum GroupTag {}
public enum TagTag {}

public typealias EntryID = Identifier<EntryTag>
public typealias GroupID = Identifier<GroupTag>
public typealias TagID = Identifier<TagTag>
