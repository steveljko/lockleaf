import CoreModels
import Foundation

/// Actor-isolated SQLite implementation of `MetadataStore`. The actor guarantees
/// serialized access to the underlying connection, so the SQLite handle never
/// crosses threads concurrently.
public actor SQLiteMetadataStore: MetadataStore {
    private let db: SQLiteDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Open (creating if needed) the database at `path` and run migrations.
    public init(path: String) throws {
        let db = try SQLiteDatabase(path: path)
        try db.migrate(Schema.migrations)
        self.db = db
    }

    /// In-memory database for tests.
    public static func inMemory() throws -> SQLiteMetadataStore {
        try SQLiteMetadataStore(path: ":memory:")
    }

    // MARK: - Groups

    public func fetchGroups() throws -> [Group] {
        try db.query("SELECT id, name, avatar, color, parent_id, sort_order, is_collapsed, created_at, modified_at FROM groups ORDER BY sort_order, name;") { row in
            Group(
                id: GroupID(UUID(uuidString: row.text(0)) ?? UUID()),
                name: row.text(1),
                avatar: try self.decode(Avatar.self, row.text(2)),
                color: AccentColor(rawValue: row.text(3)) ?? .default,
                parentID: row.optionalText(4).flatMap { UUID(uuidString: $0) }.map(GroupID.init),
                sortOrder: Int(row.int(5)),
                isCollapsed: row.bool(6),
                createdAt: Date(timeIntervalSince1970: row.double(7)),
                modifiedAt: Date(timeIntervalSince1970: row.double(8))
            )
        }
    }

    public func upsert(_ group: Group) throws {
        try db.run(
            """
            INSERT INTO groups (id, name, avatar, color, parent_id, sort_order, is_collapsed, created_at, modified_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name, avatar=excluded.avatar, color=excluded.color,
                parent_id=excluded.parent_id, sort_order=excluded.sort_order,
                is_collapsed=excluded.is_collapsed, modified_at=excluded.modified_at;
            """,
            [
                .text(group.id.rawValue.uuidString),
                .text(group.name),
                .text(try encode(group.avatar)),
                .text(group.color.rawValue),
                group.parentID.map { .text($0.rawValue.uuidString) } ?? .null,
                .int(Int64(group.sortOrder)),
                .int(group.isCollapsed ? 1 : 0),
                .double(group.createdAt.timeIntervalSince1970),
                .double(group.modifiedAt.timeIntervalSince1970),
            ]
        )
    }

    public func deleteGroup(_ id: GroupID) throws {
        try db.run("DELETE FROM groups WHERE id = ?;", [.text(id.rawValue.uuidString)])
    }

    // MARK: - Entries

    public func fetchEntries() throws -> [Entry] {
        let tagMap = try entryTagMap()
        return try db.query(
            "SELECT id, name, issuer, secret_ref, parameters, avatar, color, notes, group_id, is_favorite, is_pinned, created_at, modified_at, sort_order FROM entries ORDER BY sort_order, name;"
        ) { row in
            let id = EntryID(UUID(uuidString: row.text(0)) ?? UUID())
            return Entry(
                id: id,
                name: row.text(1),
                issuer: row.text(2),
                secretRef: SecretReference(account: row.text(3)),
                parameters: try self.decode(OTPParameters.self, row.text(4)),
                avatar: try self.decode(Avatar.self, row.text(5)),
                color: AccentColor(rawValue: row.text(6)) ?? .default,
                notes: row.text(7),
                tagIDs: tagMap[id] ?? [],
                groupID: row.optionalText(8).flatMap { UUID(uuidString: $0) }.map(GroupID.init),
                isFavorite: row.bool(9),
                isPinned: row.bool(10),
                createdAt: Date(timeIntervalSince1970: row.double(11)),
                modifiedAt: Date(timeIntervalSince1970: row.double(12)),
                sortOrder: Int(row.int(13))
            )
        }
    }

    public func fetchEntry(_ id: EntryID) throws -> Entry? {
        try fetchEntries().first { $0.id == id }
    }

    public func upsert(_ entry: Entry) throws {
        try db.transaction {
            try db.run(
                """
                INSERT INTO entries (id, name, issuer, secret_ref, parameters, avatar, color, notes, group_id, is_favorite, is_pinned, created_at, modified_at, sort_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name=excluded.name, issuer=excluded.issuer, secret_ref=excluded.secret_ref,
                    parameters=excluded.parameters, avatar=excluded.avatar, color=excluded.color,
                    notes=excluded.notes, group_id=excluded.group_id, is_favorite=excluded.is_favorite,
                    is_pinned=excluded.is_pinned, modified_at=excluded.modified_at, sort_order=excluded.sort_order;
                """,
                [
                    .text(entry.id.rawValue.uuidString),
                    .text(entry.name),
                    .text(entry.issuer),
                    .text(entry.secretRef.account),
                    .text(try encode(entry.parameters)),
                    .text(try encode(entry.avatar)),
                    .text(entry.color.rawValue),
                    .text(entry.notes),
                    entry.groupID.map { .text($0.rawValue.uuidString) } ?? .null,
                    .int(entry.isFavorite ? 1 : 0),
                    .int(entry.isPinned ? 1 : 0),
                    .double(entry.createdAt.timeIntervalSince1970),
                    .double(entry.modifiedAt.timeIntervalSince1970),
                    .int(Int64(entry.sortOrder)),
                ]
            )
            try db.run("DELETE FROM entry_tags WHERE entry_id = ?;", [.text(entry.id.rawValue.uuidString)])
            for tagID in entry.tagIDs {
                try db.run(
                    "INSERT OR IGNORE INTO entry_tags (entry_id, tag_id) VALUES (?, ?);",
                    [.text(entry.id.rawValue.uuidString), .text(tagID.rawValue.uuidString)]
                )
            }
        }
    }

    public func deleteEntry(_ id: EntryID) throws {
        try db.run("DELETE FROM entries WHERE id = ?;", [.text(id.rawValue.uuidString)])
    }

    private func entryTagMap() throws -> [EntryID: [TagID]] {
        var map: [EntryID: [TagID]] = [:]
        let rows = try db.query("SELECT entry_id, tag_id FROM entry_tags;") {
            (EntryID(UUID(uuidString: $0.text(0)) ?? UUID()), TagID(UUID(uuidString: $0.text(1)) ?? UUID()))
        }
        for (entryID, tagID) in rows {
            map[entryID, default: []].append(tagID)
        }
        return map
    }

    // MARK: - Tags

    public func fetchTags() throws -> [Tag] {
        try db.query("SELECT id, name, color FROM tags ORDER BY name;") {
            Tag(
                id: TagID(UUID(uuidString: $0.text(0)) ?? UUID()),
                name: $0.text(1),
                color: AccentColor(rawValue: $0.text(2)) ?? .gray
            )
        }
    }

    public func upsert(_ tag: Tag) throws {
        try db.run(
            "INSERT INTO tags (id, name, color) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, color=excluded.color;",
            [.text(tag.id.rawValue.uuidString), .text(tag.name), .text(tag.color.rawValue)]
        )
    }

    public func deleteTag(_ id: TagID) throws {
        try db.run("DELETE FROM tags WHERE id = ?;", [.text(id.rawValue.uuidString)])
    }

    // MARK: - Recents

    public func recordUsage(of entryID: EntryID, at date: Date) throws {
        try db.run(
            "INSERT INTO recent_items (entry_id, used_at) VALUES (?, ?) ON CONFLICT(entry_id) DO UPDATE SET used_at=excluded.used_at;",
            [.text(entryID.rawValue.uuidString), .double(date.timeIntervalSince1970)]
        )
    }

    public func fetchRecentEntryIDs(limit: Int) throws -> [EntryID] {
        try db.query("SELECT entry_id FROM recent_items ORDER BY used_at DESC LIMIT ?;", [.int(Int64(limit))]) {
            EntryID(UUID(uuidString: $0.text(0)) ?? UUID())
        }
    }

    // MARK: - Settings

    public func loadSettingsJSON() throws -> Data? {
        let rows = try db.query("SELECT value FROM settings WHERE key = 'app';") { $0.text(0) }
        return rows.first.flatMap { $0.data(using: .utf8) }
    }

    public func saveSettingsJSON(_ data: Data) throws {
        let json = String(data: data, encoding: .utf8) ?? "{}"
        try db.run(
            "INSERT INTO settings (key, value) VALUES ('app', ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value;",
            [.text(json)]
        )
    }

    // MARK: - Codable column helpers

    private func encode<T: Encodable>(_ value: T) throws -> String {
        String(data: try encoder.encode(value), encoding: .utf8) ?? "null"
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw AppError.persistence("invalid column JSON")
        }
        return try decoder.decode(type, from: data)
    }
}
