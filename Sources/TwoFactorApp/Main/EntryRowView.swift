import CoreModels
import DomainServices
import SwiftUI

/// A single, minimal entry row.
///
/// Clickable model: the **code is a capsule button** that always reads as
/// tappable (faint fill, brightening on hover, pointing-hand cursor) — one
/// obvious target for the app's primary action, copy. Favorite/pin reveal on
/// hover so the resting state stays clean. The row itself stays selectable for
/// the keyboard-driven Entry menu, and double-click anywhere also copies.
///
/// Responsiveness: the title flexes and truncates while the code capsule keeps a
/// fixed intrinsic size and higher layout priority, so codes never clip.
struct EntryRowView: View {
    let entry: Entry

    @Environment(AppModel.self) private var model
    @Environment(Library.self) private var library
    @State private var justCopied = false
    @State private var rowHovering = false

    var body: some View {
        HStack(spacing: 11) {
            AvatarView(avatar: entry.avatar, color: entry.color, seed: displayTitle,
                       size: 30, brandHint: entry.issuer)

            VStack(alignment: .leading, spacing: 0) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if hasSubtitle {
                    Text(entry.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            quickActions
                .opacity(rowHovering ? 1 : 0)
                .allowsHitTesting(rowHovering)
                .animation(.easeOut(duration: 0.12), value: rowHovering)

            codeCapsule
                .layoutPriority(1)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { rowHovering = $0 }
        .onTapGesture(count: 2, perform: copy)
        .contextMenu { contextMenu }
        .swipeActions(edge: .trailing) {
            Button("Copy", systemImage: "doc.on.doc", action: copy).tint(.accentColor)
        }
        .swipeActions(edge: .leading) {
            Button(entry.isFavorite ? "Unfavorite" : "Favorite",
                   systemImage: entry.isFavorite ? "star.slash" : "star") {
                library.toggleFavorite(entry)
            }
            .tint(.yellow)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
        .accessibilityHint("Double-tap to copy the current code")
    }

    // MARK: - Pieces

    /// Code + ring inside a capsule that always looks tappable.
    private var codeCapsule: some View {
        Button(action: copy) {
            Group {
                if justCopied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else {
                    CodeDisplay(entry: entry, fontSize: 16, ringSize: 18)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .fixedSize()
            .background(CapsuleFill())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help("Copy code (⇧⌘C)")
        .animation(.snappy(duration: 0.2), value: justCopied)
    }

    private var quickActions: some View {
        HStack(spacing: 1) {
            iconButton(entry.isFavorite ? "star.fill" : "star",
                       tint: entry.isFavorite ? .yellow : .secondary,
                       help: entry.isFavorite ? "Remove favorite" : "Add to favorites") {
                library.toggleFavorite(entry)
            }
            iconButton(entry.isPinned ? "pin.fill" : "pin",
                       tint: entry.isPinned ? .orange : .secondary,
                       help: entry.isPinned ? "Unpin" : "Pin") {
                library.togglePin(entry)
            }
        }
    }

    private func iconButton(_ symbol: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .hoverHighlight(cornerRadius: 5)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(help)
    }

    private var displayTitle: String {
        entry.issuer.isEmpty ? entry.name : entry.issuer
    }

    private var hasSubtitle: Bool {
        !entry.name.isEmpty && !entry.issuer.isEmpty
    }

    private func copy() {
        model.copyCode(for: entry)
        withAnimation(.snappy) { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.snappy) { justCopied = false }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy Code", systemImage: "doc.on.doc", action: copy)
        Button("Edit…", systemImage: "pencil") {
            model.selectedEntryID = entry.id
            model.editSelected()
        }
        Divider()
        Button(entry.isFavorite ? "Remove Favorite" : "Add to Favorites",
               systemImage: entry.isFavorite ? "star.slash" : "star") {
            library.toggleFavorite(entry)
        }
        Button(entry.isPinned ? "Unpin" : "Pin",
               systemImage: entry.isPinned ? "pin.slash" : "pin") {
            library.togglePin(entry)
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            if model.selectedEntryID == entry.id { model.selectedEntryID = nil }
            library.delete(entry)
        }
    }
}

/// A capsule background that intensifies on hover — the standing affordance that
/// marks the code as a button without adding chrome.
private struct CapsuleFill: View {
    @State private var hovering = false
    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
