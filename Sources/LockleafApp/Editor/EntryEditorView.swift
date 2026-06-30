import CoreModels
import DomainServices
import SwiftUI

/// Edit metadata for an existing entry. The secret is not shown or changed here
/// (a deliberate safety choice); replacing a secret is a separate, explicit
/// action via re-adding from QR.
struct EntryEditorView: View {
    let editing: Entry

    @Environment(\.dismiss) private var dismiss
    @Environment(Library.self) private var library

    @State private var name: String
    @State private var issuer: String
    @State private var notes: String
    @State private var avatar: Avatar
    @State private var color: AccentColor
    @State private var groupID: GroupID?
    @State private var isFavorite: Bool
    @State private var isPinned: Bool

    init(editing: Entry) {
        self.editing = editing
        _name = State(initialValue: editing.name)
        _issuer = State(initialValue: editing.issuer)
        _notes = State(initialValue: editing.notes)
        _avatar = State(initialValue: editing.avatar)
        _color = State(initialValue: editing.color)
        _groupID = State(initialValue: editing.groupID)
        _isFavorite = State(initialValue: editing.isFavorite)
        _isPinned = State(initialValue: editing.isPinned)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Account").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.buttonStyle(.borderedProminent)
            }
            .padding(20)
            Divider()

            Form {
                Section {
                    TextField("Issuer", text: $issuer)
                    TextField("Account", text: $name)
                }
                Section("Icon") {
                    IconPicker(avatar: $avatar, color: $color,
                               seed: issuer.isEmpty ? name : issuer, brandHint: issuer)
                }
                Section("Options") {
                    GroupPicker(selection: $groupID)
                    Toggle("Favorite", isOn: $isFavorite)
                    Toggle("Pinned", isOn: $isPinned)
                }
                Section {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 480)
    }

    private func save() {
        var updated = editing
        updated.name = name
        updated.issuer = issuer
        updated.notes = notes
        updated.avatar = avatar
        updated.color = color
        updated.groupID = groupID
        updated.isFavorite = isFavorite
        updated.isPinned = isPinned
        library.update(updated)
        dismiss()
    }
}
