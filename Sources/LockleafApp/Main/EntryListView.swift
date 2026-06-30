import CoreModels
import DomainServices
import SwiftUI

/// The middle column: the list of entries for the current selection/search.
struct EntryListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let entries = model.visibleEntries

        Group {
            if entries.isEmpty {
                EmptyStateView(isSearching: !model.searchText.isEmpty)
            } else {
                List(selection: $model.selectedEntryID) {
                    ForEach(entries) { entry in
                        EntryRowView(entry: entry)
                            .tag(entry.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(title)
    }

    private var title: String {
        switch model.selection {
        case .all: "All Codes"
        case .favorites: "Favorites"
        case .recents: "Recent"
        case .ungrouped: "Ungrouped"
        case .group(let id): model.library.groups.first { $0.id == id }?.name ?? "Group"
        }
    }
}
