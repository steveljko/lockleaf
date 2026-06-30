import CoreModels
import Foundation

/// The persistence boundary for **non-secret** metadata. Async so the SQLite
/// implementation can serialize on an actor while callers stay on the main
/// actor. A pure in-memory double can also conform for tests.
public protocol MetadataStore: Sendable {
    // Groups
    func fetchGroups() async throws -> [Group]
    func upsert(_ group: Group) async throws
    func deleteGroup(_ id: GroupID) async throws

    // Entries
    func fetchEntries() async throws -> [Entry]
    func fetchEntry(_ id: EntryID) async throws -> Entry?
    func upsert(_ entry: Entry) async throws
    func deleteEntry(_ id: EntryID) async throws

    // Tags
    func fetchTags() async throws -> [Tag]
    func upsert(_ tag: Tag) async throws
    func deleteTag(_ id: TagID) async throws

    // Recents
    func recordUsage(of entryID: EntryID, at date: Date) async throws
    func fetchRecentEntryIDs(limit: Int) async throws -> [EntryID]

    // Settings (opaque key/value JSON)
    func loadSettingsJSON() async throws -> Data?
    func saveSettingsJSON(_ data: Data) async throws
}
