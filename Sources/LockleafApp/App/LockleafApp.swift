import DomainServices
import SwiftUI

@main
struct LockleafApp: App {
    @State private var model: AppModel
    @State private var environment: AppEnvironment

    init() {
        // Fall back to an in-memory environment if the on-disk store cannot be
        // opened, so the app still launches and can surface the problem.
        let env = (try? AppEnvironment.live()) ?? AppEnvironment.preview(unlocked: false)
        _environment = State(initialValue: env)
        _model = State(initialValue: AppModel(environment: env))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.vault)
                .environment(model.library)
                .environment(model.settings)
                .environment(model.clock)
                .environment(environment)
                .preferredColorScheme(model.settings.settings.theme.colorScheme)
                .task { await model.bootstrap() }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 640)
        .windowResizability(.contentMinSize)
        .commands { AppCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
                .environment(model.vault)
                .environment(model.settings)
                .environment(environment)
                .preferredColorScheme(model.settings.settings.theme.colorScheme)
        }

        MenuBarExtra("Lockleaf", systemImage: "lock.shield") {
            MenuBarView()
                .environment(model)
                .environment(model.vault)
                .environment(model.library)
                .environment(model.clock)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar / keyboard commands. Centralizing them here means every shortcut is
/// discoverable in the menu bar (the native macOS expectation) rather than being
/// a hidden binding.
struct AppCommands: Commands {
    @Bindable var model: AppModel

    private var locked: Bool { model.vault.isLocked }
    private var noSelection: Bool { model.selectedEntry == nil }

    var body: some Commands {
        // File ▸ New Entry
        CommandGroup(replacing: .newItem) {
            Button("New Entry…") { post(.newEntryRequested) }
                .keyboardShortcut("n")
                .disabled(locked)
        }

        // Edit ▸ Find (focus the search field)
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find") { post(.focusSearchRequested) }
                .keyboardShortcut("f")
                .disabled(locked)
            Button("Copy Code") { model.copySelectedCode() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(locked)
        }

        // A dedicated Entry menu for the per-item actions.
        CommandMenu("Entry") {
            Button("Copy Code") { model.copySelectedCode() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(locked || noSelection)
            Button("Edit…") { model.editSelected() }
                .keyboardShortcut("e")
                .disabled(locked || noSelection)
            Divider()
            Button(model.selectedEntry?.isFavorite == true ? "Remove Favorite" : "Add to Favorites") {
                model.toggleFavoriteSelected()
            }
            .keyboardShortcut("d")
            .disabled(locked || noSelection)
            Button(model.selectedEntry?.isPinned == true ? "Unpin" : "Pin") {
                model.togglePinSelected()
            }
            .keyboardShortcut("p")
            .disabled(locked || noSelection)
            Divider()
            Button("Delete", role: .destructive) { model.deleteSelected() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(locked || noSelection)
        }

        // View ▸ jump to sidebar sections (⌘1…⌘4) and list navigation.
        CommandGroup(after: .sidebar) {
            Button("All Codes") { model.selection = .all }
                .keyboardShortcut("1", modifiers: .command)
            Button("Favorites") { model.selection = .favorites }
                .keyboardShortcut("2", modifiers: .command)
            Button("Recent") { model.selection = .recents }
                .keyboardShortcut("3", modifiers: .command)
            Button("Ungrouped") { model.selection = .ungrouped }
                .keyboardShortcut("4", modifiers: .command)
            Divider()
            Button("Select Next Code") { model.selectAdjacentEntry(offset: 1) }
                .keyboardShortcut(.downArrow, modifiers: .option)
                .disabled(locked)
            Button("Select Previous Code") { model.selectAdjacentEntry(offset: -1) }
                .keyboardShortcut(.upArrow, modifiers: .option)
                .disabled(locked)
        }

        // App ▸ Lock
        CommandGroup(after: .appInfo) {
            Button("Lock Vault") { model.lock() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(locked)
        }
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

extension Notification.Name {
    static let newEntryRequested = Notification.Name("newEntryRequested")
    static let editEntryRequested = Notification.Name("editEntryRequested")
    static let focusSearchRequested = Notification.Name("focusSearchRequested")
}
