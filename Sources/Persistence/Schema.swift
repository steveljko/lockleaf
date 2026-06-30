import Foundation

/// Versioned schema migrations. `user_version` (a SQLite PRAGMA) records the
/// applied version so upgrades are forward-only and idempotent.
///
/// IMPORTANT: there is no `secret` column anywhere. SQLite stores metadata only.
enum Schema {
    static let migrations: [String] = [
        // v1 — initial schema
        """
        CREATE TABLE groups (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            color TEXT NOT NULL,
            parent_id TEXT REFERENCES groups(id) ON DELETE SET NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_collapsed INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            modified_at REAL NOT NULL
        );

        CREATE TABLE entries (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            issuer TEXT NOT NULL,
            secret_ref TEXT NOT NULL,
            parameters TEXT NOT NULL,
            avatar TEXT NOT NULL,
            color TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            group_id TEXT REFERENCES groups(id) ON DELETE SET NULL,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            modified_at REAL NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE tags (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            color TEXT NOT NULL
        );

        CREATE TABLE entry_tags (
            entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (entry_id, tag_id)
        );

        CREATE TABLE recent_items (
            entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            used_at REAL NOT NULL,
            PRIMARY KEY (entry_id)
        );

        CREATE TABLE settings (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );

        CREATE INDEX idx_entries_group ON entries(group_id);
        CREATE INDEX idx_entries_favorite ON entries(is_favorite);
        CREATE INDEX idx_entries_name ON entries(name);
        CREATE INDEX idx_groups_parent ON groups(parent_id);
        """,
    ]
}
