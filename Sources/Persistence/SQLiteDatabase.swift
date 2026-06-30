import CoreModels
import Foundation
import SQLite3

/// Minimal, synchronous SQLite wrapper over the system `SQLite3` module. Not
/// thread-safe on its own — callers (the `SQLiteMetadataStore` actor) serialize
/// access. Kept deliberately small and auditable rather than pulling in an ORM.
final class SQLiteDatabase {
    private var handle: OpaquePointer?

    /// SQLite wants this sentinel to copy bound text/blob buffers.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw AppError.persistence("open failed: \(message)")
        }
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA synchronous = NORMAL;")
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    /// Run a statement that returns no rows.
    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw AppError.persistence(message)
        }
    }

    enum Value {
        case text(String)
        case int(Int64)
        case double(Double)
        case blob(Data)
        case null
    }

    /// Run a write statement with positional bindings.
    func run(_ sql: String, _ bindings: [Value] = []) throws {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw AppError.persistence(lastError)
        }
    }

    /// Run a query and map each row.
    func query<T>(_ sql: String, _ bindings: [Value] = [], _ map: (Row) throws -> T) throws -> [T] {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try map(Row(statement: statement)))
        }
        return results
    }

    /// Apply forward-only migrations, tracking progress in `PRAGMA user_version`.
    func migrate(_ migrations: [String]) throws {
        let current = try query("PRAGMA user_version;") { Int($0.int(0)) }.first ?? 0
        for (index, sql) in migrations.enumerated() where index >= current {
            try transaction {
                try execute(sql)
                try execute("PRAGMA user_version = \(index + 1);")
            }
        }
    }

    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    // MARK: - Private

    private var lastError: String { String(cString: sqlite3_errmsg(handle)) }

    private func prepare(_ sql: String, _ bindings: [Value]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AppError.persistence("prepare failed: \(lastError)")
        }
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let s): sqlite3_bind_text(statement, position, s, -1, Self.transient)
            case .int(let i): sqlite3_bind_int64(statement, position, i)
            case .double(let d): sqlite3_bind_double(statement, position, d)
            case .blob(let d): d.withUnsafeBytes { _ = sqlite3_bind_blob(statement, position, $0.baseAddress, Int32(d.count), Self.transient) }
            case .null: sqlite3_bind_null(statement, position)
            }
        }
        return statement
    }

    /// Lightweight typed accessor for a result row.
    struct Row {
        let statement: OpaquePointer?

        func text(_ column: Int32) -> String {
            guard let c = sqlite3_column_text(statement, column) else { return "" }
            return String(cString: c)
        }
        func optionalText(_ column: Int32) -> String? {
            sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : text(column)
        }
        func int(_ column: Int32) -> Int64 { sqlite3_column_int64(statement, column) }
        func bool(_ column: Int32) -> Bool { int(column) != 0 }
        func double(_ column: Int32) -> Double { sqlite3_column_double(statement, column) }
    }
}
