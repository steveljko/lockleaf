import CoreModels
import DomainServices
import SwiftUI

/// Create or edit a group: name, color, and an SF Symbol icon.
struct GroupEditorView: View {
    let group: CoreModels.Group?

    @Environment(\.dismiss) private var dismiss
    @Environment(Library.self) private var library

    @State private var name: String
    @State private var color: AccentColor
    @State private var symbol: String

    private static let symbols = [
        "folder", "person", "briefcase", "banknote", "server.rack",
        "building.2", "cart", "gamecontroller", "cloud", "house", "globe", "star",
    ]

    init(group: CoreModels.Group?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _color = State(initialValue: group?.color ?? .blue)
        if case let .symbol(name) = group?.avatar { _symbol = State(initialValue: name) }
        else { _symbol = State(initialValue: "folder") }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(group == nil ? "New Group" : "Edit Group").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
            Divider()

            Form {
                Section {
                    HStack {
                        AvatarView(avatar: .symbol(name: symbol), color: color, seed: name, size: 48)
                        TextField("Name", text: $name, prompt: Text("Work"))
                    }
                }
                Section("Color") { ColorPickerRow(selection: $color) }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { name in
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(symbol == name ? color.color.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(symbol == name ? color.color : .secondary)
                                .onTapGesture { symbol = name }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 460)
    }

    private func save() {
        if var existing = group {
            existing.name = name
            existing.color = color
            existing.avatar = .symbol(name: symbol)
            library.update(existing)
        } else {
            library.addGroup(name: name, color: color, avatar: .symbol(name: symbol))
        }
        dismiss()
    }
}
