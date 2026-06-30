import Testing
import Foundation
import BackupKit
import CoreModels
import KeychainStore
import Persistence
import TOTPCore
import VaultKit
@testable import DomainServices

@Suite("Fuzzy matcher")
struct FuzzyMatcherTests {
    @Test("Ranks prefix and word-boundary matches highest")
    func ranking() {
        let gh = FuzzyMatcher.score(query: "gh", candidate: "GitHub")
        let insight = FuzzyMatcher.score(query: "gh", candidate: "Insight")
        #expect(gh != nil)
        #expect(insight != nil)
        #expect(gh! > insight!)
    }

    @Test("Non-subsequence returns nil")
    func noMatch() {
        #expect(FuzzyMatcher.score(query: "xyz", candidate: "GitHub") == nil)
    }

    @Test("Empty query matches everything")
    func empty() {
        #expect(FuzzyMatcher.score(query: "", candidate: "anything") == 0)
    }
}

@MainActor
@Suite("Vault gating")
struct VaultServiceTests {
    private func makeVault(unlocked: Bool) async -> (VaultService, InMemorySecretStore) {
        let secrets = InMemorySecretStore()
        let vault = VaultService(
            secretStore: secrets,
            authenticator: StubAuthenticator(),
            dateProvider: SystemDateProvider()
        )
        if unlocked { await vault.unlock() }
        return (vault, secrets)
    }

    @Test("Generating a code while locked throws vaultLocked")
    func lockedThrows() async throws {
        let (vault, _) = await makeVault(unlocked: false)
        let entry = Entry(name: "x", issuer: "y", secretRef: SecretReference(account: "a"))
        #expect(throws: AppError.vaultLocked) {
            _ = try vault.generateCode(for: entry)
        }
    }

    @Test("Generating a code while unlocked produces a 6-digit code")
    func unlockedGenerates() async throws {
        let (vault, _) = await makeVault(unlocked: true)
        try vault.storeSecret("JBSWY3DPEHPK3PXP", for: SecretReference(account: "a"))
        let entry = Entry(name: "x", issuer: "y", secretRef: SecretReference(account: "a"))
        let code = try vault.generateCode(for: entry)
        #expect(code.value.count == 6)
    }

    @Test("Locking blocks subsequent secret access")
    func relock() async throws {
        let (vault, _) = await makeVault(unlocked: true)
        try vault.storeSecret("JBSWY3DPEHPK3PXP", for: SecretReference(account: "a"))
        vault.lock()
        let entry = Entry(name: "x", issuer: "y", secretRef: SecretReference(account: "a"))
        #expect(throws: AppError.vaultLocked) { _ = try vault.generateCode(for: entry) }
    }
}

@MainActor
@Suite("Library")
struct LibraryTests {
    private func makeLibrary() async throws -> Library {
        let store = try SQLiteMetadataStore.inMemory()
        let vault = VaultService(secretStore: InMemorySecretStore(), authenticator: StubAuthenticator(), dateProvider: SystemDateProvider())
        await vault.unlock()
        return Library(store: store, vault: vault, dateProvider: SystemDateProvider())
    }

    @Test("Adds an entry from an otpauth URI")
    func addFromURI() async throws {
        let library = try await makeLibrary()
        let uri = try OTPAuthURI(string: "otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub")
        let entry = try library.addEntry(from: uri)
        #expect(entry.issuer == "GitHub")
        #expect(library.entries.count == 1)
    }

    @Test("Search ranks the best match first")
    func search() async throws {
        let library = try await makeLibrary()
        _ = try library.addEntry(name: "alice", issuer: "GitHub", base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil)
        _ = try library.addEntry(name: "bob", issuer: "GitLab", base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil)
        let results = library.search("github")
        #expect(results.first?.issuer == "GitHub")
    }

    @Test("Deleting an entry removes its secret too")
    func deleteRemovesSecret() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let secrets = InMemorySecretStore()
        let vault = VaultService(secretStore: secrets, authenticator: StubAuthenticator(), dateProvider: SystemDateProvider())
        await vault.unlock()
        let library = Library(store: store, vault: vault, dateProvider: SystemDateProvider())
        let entry = try library.addEntry(name: "a", issuer: "b", base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil)
        #expect(secrets.exists(entry.secretRef))
        library.delete(entry)
        #expect(!secrets.exists(entry.secretRef))
    }
}

@MainActor
@Suite("iCloud backup coordinator")
struct BackupCoordinatorICloudTests {
    private struct Stack {
        let library: Library
        let secrets: InMemorySecretStore
        let coordinator: BackupCoordinator
    }

    private func makeStack(iCloudDir: URL) async throws -> Stack {
        let store = try SQLiteMetadataStore.inMemory()
        let secrets = InMemorySecretStore()
        let vault = VaultService(secretStore: secrets, authenticator: StubAuthenticator(), dateProvider: SystemDateProvider())
        await vault.unlock()
        let library = Library(store: store, vault: vault, dateProvider: SystemDateProvider())
        let coordinator = BackupCoordinator(
            library: library, vault: vault, secretStore: secrets,
            iCloud: ICloudBackupStore(directory: iCloudDir)
        )
        return Stack(library: library, secrets: secrets, coordinator: coordinator)
    }

    @Test("Backup password is stored and cleared in the Keychain seam")
    func backupPasswordLifecycle() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let stack = try await makeStack(iCloudDir: dir)

        #expect(!stack.coordinator.hasBackupPassword)
        try stack.coordinator.setBackupPassword("correct horse")
        #expect(stack.coordinator.hasBackupPassword)
        try stack.coordinator.clearBackupPassword()
        #expect(!stack.coordinator.hasBackupPassword)
    }

    @Test("Backup to iCloud round-trips into a fresh vault on restore")
    func iCloudRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Source: one entry, encrypted backup pushed to the shared iCloud dir.
        let source = try await makeStack(iCloudDir: dir)
        let entry = try source.library.addEntry(
            name: "alice", issuer: "GitHub",
            base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil
        )
        try source.coordinator.setBackupPassword("pw")
        try await source.coordinator.backUpToICloud()
        #expect(source.coordinator.iCloudBackupDate != nil)

        // Destination: empty vault restores from the same iCloud dir.
        let dest = try await makeStack(iCloudDir: dir)
        #expect(dest.library.entries.isEmpty)
        try dest.coordinator.restoreFromICloud(password: "pw")

        #expect(dest.library.entries.count == 1)
        let restored = try #require(dest.library.entries.first)
        #expect(restored.id == entry.id)
        #expect(restored.issuer == "GitHub")
        #expect(dest.secrets.exists(restored.secretRef))
    }

    @Test("Restoring with the wrong password fails")
    func wrongPassword() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try await makeStack(iCloudDir: dir)
        _ = try source.library.addEntry(name: "a", issuer: "b", base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil)
        try source.coordinator.setBackupPassword("right")
        try await source.coordinator.backUpToICloud()

        let dest = try await makeStack(iCloudDir: dir)
        #expect(throws: AppError.self) {
            try dest.coordinator.restoreFromICloud(password: "wrong")
        }
    }
}

@MainActor
@Suite("Library revision")
struct LibraryRevisionTests {
    @Test("Content mutations bump the revision counter")
    func bumps() async throws {
        let store = try SQLiteMetadataStore.inMemory()
        let vault = VaultService(secretStore: InMemorySecretStore(), authenticator: StubAuthenticator(), dateProvider: SystemDateProvider())
        await vault.unlock()
        let library = Library(store: store, vault: vault, dateProvider: SystemDateProvider())

        let start = library.revision
        let entry = try library.addEntry(name: "a", issuer: "b", base32Secret: "JBSWY3DPEHPK3PXP", parameters: .standard, groupID: nil)
        #expect(library.revision > start)

        let afterAdd = library.revision
        library.delete(entry)
        #expect(library.revision > afterAdd)
    }
}

struct StubAuthenticator: Authenticator {
    var biometryKind: BiometryKind { .touchID }
    var canAuthenticate: Bool { true }
    func authenticate(reason: String) async throws {}
}
