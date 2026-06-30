import CoreModels
import DomainServices
import SwiftUI

/// The primary three-column layout: groups sidebar, entry list, detail pane.
struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(Library.self) private var library

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAddEntry = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var model = model

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            EntryListView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
                .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search codes")
                .searchFocused($searchFocused)
        } detail: {
            if let entry = model.selectedEntry {
                EntryDetailView(entry: entry)
            } else {
                EmptyDetailView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddEntry = true } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .help("Add a new account (⌘N)")
            }
            ToolbarItem(placement: .automatic) {
                Button { model.lock() } label: {
                    Label("Lock", systemImage: "lock.fill")
                }
                .help("Lock the vault (⇧⌘L)")
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntryRequested)) { _ in
            showingAddEntry = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchRequested)) { _ in
            searchFocused = true
        }
        // Treat any in-window interaction as activity that defers auto-lock.
        .onContinuousHover { _ in model.lockCoordinator.registerActivity() }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.presentedError ?? "")
        }
    }
}
