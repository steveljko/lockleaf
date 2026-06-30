import CoreModels
import Foundation
import KeychainStore
import Observation
import Persistence
import VaultKit

/// The composition root. Constructs and owns the long-lived services and wires
/// their dependencies. Views receive this via the SwiftUI environment; nothing
/// reaches for globals or singletons.
@MainActor
@Observable
public final class AppEnvironment {
    public let settingsStore: SettingsStore
    public let vault: VaultService
    public let library: Library
    public let clipboard: ClipboardManager
    public let backups: BackupCoordinator

    private init(
        settingsStore: SettingsStore,
        vault: VaultService,
        library: Library,
        clipboard: ClipboardManager
    ) {
        self.settingsStore = settingsStore
        self.vault = vault
        self.library = library
        self.clipboard = clipboard
        self.backups = BackupCoordinator(library: library, vault: vault)
    }

    /// Production environment: SQLite on disk + Keychain-backed secrets +
    /// LocalAuthentication.
    public static func live() throws -> AppEnvironment {
        let store = try SQLiteMetadataStore(path: try databaseURL().path)
        let secretStore = KeychainSecretStore()
        return make(store: store, secretStore: secretStore, authenticator: LocalAuthenticator())
    }

    /// In-memory environment for previews and tests. Optionally start unlocked.
    public static func preview(unlocked: Bool = true) -> AppEnvironment {
        let store = try! SQLiteMetadataStore.inMemory()
        let env = make(
            store: store,
            secretStore: InMemorySecretStore(),
            authenticator: AlwaysSucceedAuthenticator()
        )
        if unlocked { Task { await env.vault.unlock() } }
        return env
    }

    private static func make(store: MetadataStore, secretStore: SecretStore, authenticator: Authenticator) -> AppEnvironment {
        let date = SystemDateProvider()
        let vault = VaultService(secretStore: secretStore, authenticator: authenticator, dateProvider: date)
        let library = Library(store: store, vault: vault, dateProvider: date)
        return AppEnvironment(
            settingsStore: SettingsStore(store: store),
            vault: vault,
            library: library,
            clipboard: ClipboardManager()
        )
    }

    /// Load persisted state. Call once at launch.
    public func bootstrap() async {
        await settingsStore.load()
        await library.load()
    }

    private static func databaseURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let directory = support.appendingPathComponent("TwoFactor", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("metadata.sqlite")
    }
}

/// Test/preview authenticator that always succeeds without UI.
struct AlwaysSucceedAuthenticator: Authenticator {
    var biometryKind: BiometryKind { .touchID }
    var canAuthenticate: Bool { true }
    func authenticate(reason: String) async throws {}
}
