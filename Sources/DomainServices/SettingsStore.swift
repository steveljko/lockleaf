import CoreModels
import Foundation
import Observation
import Persistence

/// Loads and persists `AppSettings` as JSON via the metadata store. Observable so
/// SwiftUI updates when preferences change.
@MainActor
@Observable
public final class SettingsStore {
    public private(set) var settings: AppSettings = .default

    private let store: MetadataStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: MetadataStore) {
        self.store = store
    }

    public func load() async {
        do {
            if let data = try await store.loadSettingsJSON() {
                settings = try decoder.decode(AppSettings.self, from: data)
            }
        } catch {
            settings = .default
        }
    }

    /// Mutate settings and persist. The closure form keeps reads and writes
    /// atomic from the caller's perspective.
    public func update(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        let snapshot = settings
        Task { [store, encoder] in
            if let data = try? encoder.encode(snapshot) {
                try? await store.saveSettingsJSON(data)
            }
        }
    }
}
