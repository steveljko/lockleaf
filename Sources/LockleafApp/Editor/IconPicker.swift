import AppKit
import CoreModels
import SwiftUI

/// Reusable icon chooser for an entry's avatar. Four modes:
/// - **Auto** — initials, upgraded to a brand icon when the issuer is known.
/// - **Emoji** — pick or type a single emoji.
/// - **Symbol** — choose an SF Symbol.
/// - **Image** — upload a picture (stored locally via `ImageStore`).
///
/// Designed to drop into a `Form` `Section`.
struct IconPicker: View {
    @Binding var avatar: Avatar
    @Binding var color: AccentColor
    /// Used to render the live preview (initials / brand match).
    var seed: String
    var brandHint: String?

    @State private var mode: Mode

    enum Mode: String, CaseIterable, Identifiable {
        case auto = "Auto", emoji = "Emoji", symbol = "Symbol", image = "Image"
        var id: String { rawValue }
    }

    private static let emojis = ["🔐", "🛡️", "🔑", "💳", "🏦", "📧", "☁️", "💼", "🎮", "🛒", "💬", "📱", "🌐", "⭐️", "🚀", "🐙"]
    private static let symbols = [
        "person.fill", "envelope.fill", "lock.fill", "key.fill", "creditcard.fill",
        "building.columns.fill", "briefcase.fill", "cart.fill", "gamecontroller.fill",
        "cloud.fill", "server.rack", "terminal.fill", "globe", "bolt.fill",
        "bitcoinsign.circle.fill", "star.fill", "heart.fill", "flame.fill",
    ]

    init(avatar: Binding<Avatar>, color: Binding<AccentColor>, seed: String, brandHint: String? = nil) {
        _avatar = avatar
        _color = color
        self.seed = seed
        self.brandHint = brandHint
        _mode = State(initialValue: Self.mode(for: avatar.wrappedValue))
    }

    var body: some View {
        // Live preview
        HStack {
            Spacer()
            AvatarView(avatar: avatar, color: color, seed: seed, size: 56, brandHint: brandHint)
            Spacer()
        }
        .padding(.vertical, 4)

        Picker("Icon", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, newMode in apply(newMode) }

        switch mode {
        case .auto:
            Text("Uses the service's icon automatically, or initials.")
                .font(.caption).foregroundStyle(.secondary)
        case .emoji:
            emojiGrid
        case .symbol:
            symbolGrid
        case .image:
            imageControls
        }

        if mode != .image {
            ColorPickerRow(selection: $color)
        }
    }

    // MARK: - Mode panes

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
            ForEach(Self.emojis, id: \.self) { glyph in
                Text(glyph)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(isSelectedEmoji(glyph) ? color.color.opacity(0.2) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .onTapGesture { avatar = .emoji(glyph) }
                    .pointerCursor()
            }
        }
        .padding(.vertical, 2)
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
            ForEach(Self.symbols, id: \.self) { name in
                Image(systemName: name)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(isSelectedSymbol(name) ? color.color.opacity(0.2) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(isSelectedSymbol(name) ? color.color : .secondary)
                    .onTapGesture { avatar = .symbol(name: name) }
                    .pointerCursor()
            }
        }
        .padding(.vertical, 2)
    }

    private var imageControls: some View {
        HStack {
            Button("Choose Image…", systemImage: "photo") { chooseImage() }
            if case .image = avatar {
                Button("Remove", role: .destructive) { apply(.auto) }
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func apply(_ newMode: Mode) {
        switch newMode {
        case .auto: avatar = .initials
        case .emoji: if case .emoji = avatar {} else { avatar = .emoji(Self.emojis[0]) }
        case .symbol: if case .symbol = avatar {} else { avatar = .symbol(name: Self.symbols[0]) }
        case .image: break // wait for the user to pick a file
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url),
           let fileName = ImageStore.shared.save(image) {
            avatar = .image(fileName: fileName)
            mode = .image
        }
    }

    private func isSelectedEmoji(_ glyph: String) -> Bool {
        if case .emoji(let g) = avatar { return g == glyph }
        return false
    }

    private func isSelectedSymbol(_ name: String) -> Bool {
        if case .symbol(let n) = avatar { return n == name }
        return false
    }

    private static func mode(for avatar: Avatar) -> Mode {
        switch avatar {
        case .initials: .auto
        case .emoji: .emoji
        case .symbol: .symbol
        case .image: .image
        }
    }
}
