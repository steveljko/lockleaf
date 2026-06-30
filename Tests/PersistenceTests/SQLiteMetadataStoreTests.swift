import Testing
import Foundation
import CoreModels
@testable import Persistence

@Suite("SQLite metadata store")
struct SQLiteMetadataStoreTests {

    @Test("Round-trips a group")
    func groupRoundTrip() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let group = Group(name: "Work", color: .indigo, sortOrder: 1)
        try await store.upsert(group)

        let fetched = try await store.fetchGroups()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Work")
        #expect(fetched.first?.color == .indigo)
    }

    @Test("Round-trips an entry with tags and parameters")
    func entryRoundTrip() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let tag = Tag(name: "cloud")
        try await store.upsert(tag)

        let id = EntryID()
        let entry = Entry(
            id: id,
            name: "alice@example.com",
            issuer: "GitHub",
            secretRef: SecretReference(for: id),
            parameters: OTPParameters(algorithm: .sha256, digits: 8, period: 60),
            notes: "primary",
            tagIDs: [tag.id],
            isFavorite: true
        )
        try await store.upsert(entry)

        let fetched = try #require(try await store.fetchEntry(id))
        #expect(fetched.issuer == "GitHub")
        #expect(fetched.parameters.algorithm == .sha256)
        #expect(fetched.parameters.digits == 8)
        #expect(fetched.isFavorite)
        #expect(fetched.tagIDs == [tag.id])
        // The secret column is just a reference, never the secret itself.
        #expect(fetched.secretRef.account == id.rawValue.uuidString)
    }

    @Test("Deleting an entry removes it")
    func deleteEntry() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let id = EntryID()
        try await store.upsert(Entry(id: id, name: "x", issuer: "y", secretRef: SecretReference(for: id)))
        try await store.deleteEntry(id)
        #expect(try await store.fetchEntries().isEmpty)
    }

    @Test("Settings JSON round-trips")
    func settings() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let data = Data(#"{"theme":"dark"}"#.utf8)
        try await store.saveSettingsJSON(data)
        let loaded = try await store.loadSettingsJSON()
        #expect(loaded == data)
    }

    @Test("Recents are ordered by most recent use")
    func recents() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let a = EntryID(); let b = EntryID()
        for id in [a, b] {
            try await store.upsert(Entry(id: id, name: "n", issuer: "i", secretRef: SecretReference(for: id)))
        }
        try await store.recordUsage(of: a, at: Date(timeIntervalSince1970: 100))
        try await store.recordUsage(of: b, at: Date(timeIntervalSince1970: 200))
        let recents = try await store.fetchRecentEntryIDs(limit: 10)
        #expect(recents.first == b)
    }
}
