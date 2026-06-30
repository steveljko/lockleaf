import CoreModels
import Foundation
import Observation
import Persistence
import TOTPCore

/// The in-memory, observable source of truth for groups, entries, and tags.
/// Reads come from this cache (fast, synchronous for the UI); writes go through
/// to the `MetadataStore` and, for secrets, the `VaultService`.
@MainActor
@Observable
public final class Library {
    public private(set) var groups: [Group] = []
    public private(set) var entries: [Entry] = []
    public private(set) var tags: [Tag] = []
    public private(set) var recentEntryIDs: [EntryID] = []

    private let store: MetadataStore
    private let vault: VaultService
    private let dateProvider: DateProvider

    public init(store: MetadataStore, vault: VaultService, dateProvider: DateProvider) {
        self.store = store
        self.vault = vault
        self.dateProvider = dateProvider
    }

    public func load() async {
        async let groups = try? store.fetchGroups()
        async let entries = try? store.fetchEntries()
        async let tags = try? store.fetchTags()
        async let recents = try? store.fetchRecentEntryIDs(limit: 10)
        self.groups = (await groups) ?? []
        self.entries = (await entries) ?? []
        self.tags = (await tags) ?? []
        self.recentEntryIDs = (await recents) ?? []
    }

    // MARK: - Entries

    /// Create an entry from a parsed `otpauth://` URI. Stores the secret in the
    /// vault and the metadata in SQLite.
    @discardableResult
    public func addEntry(from uri: OTPAuthURI, groupID: GroupID? = nil) throws -> Entry {
        let id = EntryID()
        let reference = SecretReference(for: id)
        try vault.storeSecret(uri.base32Secret, for: reference)

        let entry = Entry(
            id: id,
            name: uri.accountName.isEmpty ? uri.issuer : uri.accountName,
            issuer: uri.issuer,
            secretRef: reference,
            parameters: uri.parameters,
            groupID: groupID
        )
        persist(entry)
        entries.append(entry)
        return entry
    }

    /// Create an entry from manual field input.
    @discardableResult
    public func addEntry(
        name: String,
        issuer: String,
        base32Secret: String,
        parameters: OTPParameters,
        groupID: GroupID?,
        avatar: Avatar = .default,
        color: AccentColor = .default,
        notes: String = ""
    ) throws -> Entry {
        let id = EntryID()
        let reference = SecretReference(for: id)
        try vault.storeSecret(base32Secret, for: reference)
        let entry = Entry(
            id: id, name: name, issuer: issuer, secretRef: reference,
            parameters: parameters, avatar: avatar, color: color,
            notes: notes, groupID: groupID
        )
        persist(entry)
        entries.append(entry)
        return entry
    }

    /// Update mutable metadata of an existing entry (not the secret).
    public func update(_ entry: Entry) {
        var updated = entry
        updated.modifiedAt = dateProvider.now()
        persist(updated)
        if let index = entries.firstIndex(where: { $0.id == updated.id }) {
            entries[index] = updated
        }
    }

    /// Replace the secret of an existing entry.
    public func replaceSecret(of entry: Entry, withBase32 base32: String) throws {
        try vault.storeSecret(base32, for: entry.secretRef)
        update(entry)
    }

    public func delete(_ entry: Entry) {
        try? vault.deleteSecret(for: entry.secretRef)
        entries.removeAll { $0.id == entry.id }
        Task { [store] in try? await store.deleteEntry(entry.id) }
    }

    public func toggleFavorite(_ entry: Entry) {
        var copy = entry
        copy.isFavorite.toggle()
        update(copy)
    }

    public func togglePin(_ entry: Entry) {
        var copy = entry
        copy.isPinned.toggle()
        update(copy)
    }

    public func recordUsage(of entry: Entry) {
        let now = dateProvider.now()
        Task { [store] in try? await store.recordUsage(of: entry.id, at: now) }
    }

    // MARK: - Groups

    @discardableResult
    public func addGroup(name: String, color: AccentColor, avatar: Avatar, parentID: GroupID? = nil) -> Group {
        let group = Group(
            name: name, avatar: avatar, color: color,
            parentID: parentID, sortOrder: groups.count
        )
        groups.append(group)
        Task { [store] in try? await store.upsert(group) }
        return group
    }

    public func update(_ group: Group) {
        var updated = group
        updated.modifiedAt = dateProvider.now()
        if let index = groups.firstIndex(where: { $0.id == updated.id }) {
            groups[index] = updated
        }
        Task { [store] in try? await store.upsert(updated) }
    }

    public func delete(_ group: Group) {
        groups.removeAll { $0.id == group.id }
        // Detach entries from the deleted group locally; the DB cascades via
        // ON DELETE SET NULL.
        for index in entries.indices where entries[index].groupID == group.id {
            entries[index].groupID = nil
        }
        Task { [store] in try? await store.deleteGroup(group.id) }
    }

    public func reorderGroups(_ ordered: [Group]) {
        for (index, group) in ordered.enumerated() {
            var copy = group
            copy.sortOrder = index
            if let i = groups.firstIndex(where: { $0.id == copy.id }) { groups[i] = copy }
            Task { [store] in try? await store.upsert(copy) }
        }
        groups.sort { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Tags

    @discardableResult
    public func addTag(name: String, color: AccentColor) -> Tag {
        let tag = Tag(name: name, color: color)
        tags.append(tag)
        Task { [store] in try? await store.upsert(tag) }
        return tag
    }

    public func delete(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        for index in entries.indices {
            entries[index].tagIDs.removeAll { $0 == tag.id }
        }
        Task { [store] in try? await store.deleteTag(tag.id) }
    }

    // MARK: - Restore (upsert from a backup, preserving IDs)

    public func adoptGroup(_ group: Group) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) { groups[index] = group }
        else { groups.append(group) }
        Task { [store] in try? await store.upsert(group) }
    }

    public func adoptTag(_ tag: Tag) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) { tags[index] = tag }
        else { tags.append(tag) }
        Task { [store] in try? await store.upsert(tag) }
    }

    public func adoptEntry(_ entry: Entry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry }
        else { entries.append(entry) }
        persist(entry)
    }

    // MARK: - Querying

    public func entries(in groupID: GroupID?) -> [Entry] {
        guard let groupID else { return entries }
        return entries.filter { $0.groupID == groupID }
    }

    public var favorites: [Entry] { entries.filter(\.isFavorite) }
    public var pinned: [Entry] { entries.filter(\.isPinned) }
    public var recents: [Entry] {
        recentEntryIDs.compactMap { id in entries.first { $0.id == id } }
    }

    /// Fuzzy search across name, issuer, notes, tags, and group name, ranked by
    /// best field score.
    public func search(_ query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }

        let tagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        let groupNames = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })

        let scored: [(Entry, Int)] = entries.compactMap { entry in
            var candidates = [entry.name, entry.issuer, entry.notes]
            candidates += entry.tagIDs.compactMap { tagNames[$0] }
            if let groupID = entry.groupID, let name = groupNames[groupID] { candidates.append(name) }

            let best = candidates.compactMap { FuzzyMatcher.score(query: trimmed, candidate: $0) }.max()
            return best.map { (entry, $0) }
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    // MARK: - Private

    private func persist(_ entry: Entry) {
        Task { [store] in try? await store.upsert(entry) }
    }
}
