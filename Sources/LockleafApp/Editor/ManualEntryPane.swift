import CoreModels
import DomainServices
import SwiftUI
import TOTPCore

/// The data captured by the manual-entry form.
struct ManualDraft {
    var name = ""
    var issuer = ""
    var secret = ""
    var notes = ""
    var avatar: Avatar = .default
    var color: AccentColor = .default
    var groupID: GroupID?
    var parameters = OTPParameters.standard
}

/// Manual add form. Validates the Base32 secret before enabling Save.
struct ManualEntryPane: View {
    let onSave: (ManualDraft) -> Void
    let onError: (String) -> Void

    @Environment(Library.self) private var library
    @State private var draft = ManualDraft()

    private var secretIsValid: Bool {
        !draft.secret.trimmingCharacters(in: .whitespaces).isEmpty
            && Base32.decode(draft.secret) != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Issuer", text: $draft.issuer, prompt: Text("GitHub"))
                TextField("Account", text: $draft.name, prompt: Text("alice@example.com"))
                SecureField("Secret (Base32)", text: $draft.secret)
                if !draft.secret.isEmpty && !secretIsValid {
                    Label("Not a valid Base32 secret", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Icon") {
                IconPicker(avatar: $draft.avatar, color: $draft.color,
                           seed: draft.issuer.isEmpty ? draft.name : draft.issuer,
                           brandHint: draft.issuer)
            }

            Section("Options") {
                GroupPicker(selection: $draft.groupID)
                OTPParametersEditor(parameters: $draft.parameters)
            }

            Section {
                TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(2...4)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            Button("Add Account") { onSave(draft) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!secretIsValid)
                .padding(.top, 8)
        }
    }
}

/// Reusable editor for algorithm / digits / period, shared by add and edit.
struct OTPParametersEditor: View {
    @Binding var parameters: OTPParameters

    var body: some View {
        Picker("Algorithm", selection: $parameters.algorithm) {
            ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        Stepper("Digits: \(parameters.digits)", value: $parameters.digits, in: 6...8)
        if parameters.kind == .totp {
            Stepper("Period: \(parameters.period)s", value: $parameters.period, in: 15...120, step: 15)
        }
    }
}

struct GroupPicker: View {
    @Binding var selection: GroupID?
    @Environment(Library.self) private var library

    var body: some View {
        Picker("Group", selection: $selection) {
            Text("None").tag(GroupID?.none)
            ForEach(library.groups) { group in
                Text(group.name).tag(GroupID?.some(group.id))
            }
        }
    }
}

struct ColorPickerRow: View {
    @Binding var selection: AccentColor

    var body: some View {
        HStack {
            Text("Color")
            Spacer()
            ForEach(AccentColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.primary, lineWidth: selection == color ? 2 : 0))
                    .onTapGesture { selection = color }
            }
        }
    }
}
