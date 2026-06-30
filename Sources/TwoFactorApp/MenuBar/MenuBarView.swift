import CoreModels
import DomainServices
import SwiftUI

/// The menu bar popover: search and copy codes (favorites first) without opening
/// the main window. Respects the lock state.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(VaultService.self) private var vault
    @Environment(Library.self) private var library

    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vault.isLocked {
                lockedState
            } else {
                content
            }
        }
        .frame(width: 320, height: 420)
    }

    private var header: some View {
        HStack {
            Image(systemName: "lock.shield.fill").foregroundStyle(.tint)
            Text("2FA").font(.headline)
            Spacer()
            if vault.isLocked {
                Button("Unlock") { Task { await model.unlock() } }
            } else {
                Button { model.lock() } label: { Image(systemName: "lock.fill") }
                    .help("Lock")
            }
        }
        .padding(10)
    }

    private var lockedState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
            Text("Vault is locked").foregroundStyle(.secondary)
            Button("Unlock with Touch ID") { Task { await model.unlock() } }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var content: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List {
                ForEach(entries) { entry in
                    MenuBarRow(entry: entry)
                }
            }
            .listStyle(.plain)
        }
    }

    private var entries: [Entry] {
        let base = query.isEmpty
            ? (library.favorites.isEmpty ? library.entries : library.favorites)
            : library.search(query)
        return Array(base.prefix(50))
    }
}

private struct MenuBarRow: View {
    let entry: Entry
    @Environment(AppModel.self) private var model
    @State private var copied = false

    var body: some View {
        Button {
            model.copyCode(for: entry)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
        } label: {
            HStack(spacing: 10) {
                AvatarView(avatar: entry.avatar, color: entry.color, seed: entry.issuer.isEmpty ? entry.name : entry.issuer, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.issuer.isEmpty ? entry.name : entry.issuer).font(.callout).lineLimit(1)
                    if !entry.name.isEmpty { Text(entry.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer()
                CodeDisplay(entry: entry, fontSize: 15, ringSize: 16)
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
