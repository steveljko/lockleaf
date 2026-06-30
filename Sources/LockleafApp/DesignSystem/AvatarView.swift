import AppKit
import CoreModels
import SwiftUI

/// Circular avatar used across the sidebar, list, and detail. Renders uploaded
/// images, emoji, SF Symbols, or deterministic initials over a tinted disc.
struct AvatarView: View {
    let avatar: Avatar
    let color: AccentColor
    let seed: String
    var size: CGFloat = Metrics.avatarMedium
    /// When the avatar is the default (`.initials`), this hint (the issuer/name)
    /// is matched against the brand catalog to auto-pick a recognizable icon.
    var brandHint: String? = nil

    /// The effective color, upgraded to the brand color for auto-resolved icons.
    private var effectiveColor: AccentColor {
        if case .initials = avatar, color == .default, let brand = resolvedBrand {
            return brand.color
        }
        return color
    }

    private var resolvedBrand: BrandCatalog.Brand? {
        guard case .initials = avatar else { return nil }
        return BrandCatalog.match(brandHint ?? seed)
    }

    var body: some View {
        ZStack {
            Circle().fill(effectiveColor.color.gradient.opacity(0.18))
            content
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(effectiveColor.color.opacity(0.22), lineWidth: 1))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch avatar {
        case .initials:
            if let brand = resolvedBrand {
                Image(systemName: brand.symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(brand.color.color)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.color)
            }
        case .emoji(let glyph):
            Text(glyph).font(.system(size: size * 0.5))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(color.color)
        case .image(let fileName):
            if let image = ImageStore.shared.load(fileName) {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(initials).font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(color.color)
            }
        }
    }

    private var initials: String {
        let words = seed.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map(String.init)
        return letters.joined().uppercased().isEmpty ? "?" : letters.joined().uppercased()
    }
}

/// Stores user-uploaded avatar images under Application Support so the database
/// holds only a file name.
final class ImageStore: Sendable {
    static let shared = ImageStore()
    private let directory: URL

    private init() {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = support.appendingPathComponent("Lockleaf/Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(_ fileName: String) -> NSImage? {
        NSImage(contentsOf: directory.appendingPathComponent(fileName))
    }

    @discardableResult
    func save(_ image: NSImage) -> String? {
        let name = UUID().uuidString + ".png"
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        try? png.write(to: directory.appendingPathComponent(name))
        return name
    }
}
