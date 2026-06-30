import CoreModels
import DomainServices
import Foundation
import Observation
import SwiftUI
import VaultKit

/// Top-level UI state and the seam between SwiftUI and the domain services.
/// Holds the composition root (`AppEnvironment`) and cross-cutting view state
/// like the current sidebar selection and search text.
@MainActor
@Observable
final class AppModel {
    let environment: AppEnvironment
    let clock = CodeClock()
    let lockCoordinator: LockCoordinator

    var selection: SidebarItem = .all
    var selectedEntryID: EntryID?
    var searchText: String = ""
    /// Set to surface a non-fatal error to the user.
    var presentedError: String?

    var vault: VaultService { environment.vault }
    var library: Library { environment.library }
    var settings: SettingsStore { environment.settingsStore }
    var clipboard: ClipboardManager { environment.clipboard }

    init(environment: AppEnvironment) {
        self.environment = environment
        self.lockCoordinator = LockCoordinator(
            vault: environment.vault,
            settings: environment.settingsStore,
            clipboard: environment.clipboard
        )
    }

    func bootstrap() async {
        await environment.bootstrap()
        clock.start()
        lockCoordinator.start()
    }

    func unlock() async {
        await vault.unlock()
        if !vault.isLocked { lockCoordinator.resetInactivityTimer() }
    }

    func lock() {
        lockCoordinator.lock()
        selectedEntryID = nil
    }

    /// Copy an entry's current code, honoring clipboard settings, and record it
    /// as recently used.
    func copyCode(for entry: Entry) {
        guard !vault.isLocked else { return }
        do {
            let code = try vault.generateCode(for: entry)
            clipboard.copy(
                code.value,
                clearAfter: settings.settings.clipboardClearSeconds,
                secure: settings.settings.secureClipboard
            )
            library.recordUsage(of: entry)
            lockCoordinator.registerActivity()
        } catch {
            presentedError = (error as? AppError)?.userMessage ?? error.localizedDescription
        }
    }

    // MARK: - Commands acting on the current selection (keyboard-driven)

    /// Copy the code for the highlighted entry. If nothing is highlighted but the
    /// list has exactly one visible entry, copy that — the common "just give me
    /// the code" case.
    func copySelectedCode() {
        let target = selectedEntry ?? (visibleEntries.count == 1 ? visibleEntries.first : nil)
        guard let target else { return }
        copyCode(for: target)
    }

    func toggleFavoriteSelected() {
        guard let entry = selectedEntry else { return }
        library.toggleFavorite(entry)
    }

    func togglePinSelected() {
        guard let entry = selectedEntry else { return }
        library.togglePin(entry)
    }

    func editSelected() {
        guard selectedEntry != nil else { return }
        NotificationCenter.default.post(name: .editEntryRequested, object: nil)
    }

    func deleteSelected() {
        guard let entry = selectedEntry else { return }
        selectedEntryID = nil
        library.delete(entry)
    }

    /// Move the highlight to the previous/next visible entry (⌥↑ / ⌥↓), wrapping.
    func selectAdjacentEntry(offset: Int) {
        let entries = visibleEntries
        guard !entries.isEmpty else { return }
        guard let current = selectedEntryID,
              let index = entries.firstIndex(where: { $0.id == current }) else {
            selectedEntryID = entries.first?.id
            return
        }
        let next = (index + offset + entries.count) % entries.count
        selectedEntryID = entries[next].id
    }

    /// The entries to show for the current selection, then filtered by search.
    var visibleEntries: [Entry] {
        let base: [Entry]
        switch selection {
        case .all: base = library.entries
        case .favorites: base = library.favorites
        case .recents: base = library.recents
        case .ungrouped: base = library.entries.filter { $0.groupID == nil }
        case .group(let id): base = library.entries(in: id)
        }

        let filtered = searchText.isEmpty
            ? base
            : library.search(searchText).filter { entry in base.contains { $0.id == entry.id } }

        // Pinned first, then favorites, then by name — unless searching, where
        // relevance order from the fuzzy matcher is preserved.
        guard searchText.isEmpty else { return filtered }
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var selectedEntry: Entry? {
        guard let id = selectedEntryID else { return nil }
        return library.entries.first { $0.id == id }
    }
}
