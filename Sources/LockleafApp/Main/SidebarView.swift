import CoreModels
import DomainServices
import SwiftUI

/// Groups sidebar with smart lists (All, Favorites, Recents) and user groups,
/// supporting drag-to-reorder and context actions.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(Library.self) private var library

    @State private var showingAddGroup = false
    @State private var editingGroup: CoreModels.Group?

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selection) {
            Section("Library") {
                label(.all, "All Codes", "square.grid.2x2", count: library.entries.count)
                label(.favorites, "Favorites", "star.fill", count: library.favorites.count)
                label(.recents, "Recent", "clock", count: nil)
                label(.ungrouped, "Ungrouped", "tray", count: library.entries.filter { $0.groupID == nil }.count)
            }

            Section("Groups") {
                ForEach(library.groups) { group in
                    groupRow(group)
                }
                .onMove { indices, destination in
                    var reordered = library.groups
                    reordered.move(fromOffsets: indices, toOffset: destination)
                    library.reorderGroups(reordered)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button { showingAddGroup = true } label: {
                Label("New Group", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .sheet(isPresented: $showingAddGroup) { GroupEditorView(group: nil) }
        .sheet(item: $editingGroup) { group in GroupEditorView(group: group) }
    }

    private func label(_ item: SidebarItem, _ title: String, _ symbol: String, count: Int?) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                if let count { Text("\(count)").foregroundStyle(.secondary).monospacedDigit() }
            }
        } icon: {
            Image(systemName: symbol)
        }
        .tag(item)
    }

    private func groupRow(_ group: CoreModels.Group) -> some View {
        Label {
            HStack {
                Text(group.name)
                Spacer()
                Text("\(library.entries(in: group.id).count)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        } icon: {
            AvatarView(avatar: group.avatar, color: group.color, seed: group.name, size: 20)
        }
        .tag(SidebarItem.group(group.id))
        .contextMenu {
            Button("Edit Group…") { editingGroup = group }
            Button("Delete Group", role: .destructive) { library.delete(group) }
        }
    }
}
