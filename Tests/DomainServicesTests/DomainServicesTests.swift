import Testing
import Foundation
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

struct StubAuthenticator: Authenticator {
    var biometryKind: BiometryKind { .touchID }
    var canAuthenticate: Bool { true }
    func authenticate(reason: String) async throws {}
}
