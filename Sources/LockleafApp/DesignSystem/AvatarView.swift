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
///
/// Avatars are never shown larger than ~56pt, so images are downscaled to a small
/// bounded size on save (capping disk and decoded-bitmap cost) and the decoded
/// `NSImage`s are cached in memory so the many places that render the same avatar
/// — sidebar, list, detail — don't each re-decode the file on every redraw.
final class ImageStore: Sendable {
    static let shared = ImageStore()
    private let directory: URL
    /// Decoded, already-downscaled avatars keyed by file name. `NSCache` evicts
    /// under memory pressure on its own.
    nonisolated(unsafe) private let cache = NSCache<NSString, NSImage>()

    /// Longest edge we keep, in pixels. Covers the 56pt preview at 2x with headroom.
    private static let maxDimension: CGFloat = 256

    private init() {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = support.appendingPathComponent("Lockleaf/Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(_ fileName: String) -> NSImage? {
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: directory.appendingPathComponent(fileName)) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    @discardableResult
    func save(_ image: NSImage) -> String? {
        let name = UUID().uuidString + ".png"
        guard let png = Self.downscaledPNG(image) else { return nil }
        try? png.write(to: directory.appendingPathComponent(name))
        cache.setObject(NSImage(data: png) ?? image, forKey: name as NSString)
        return name
    }

    /// Renders `image` into a bitmap no larger than ``maxDimension`` on its longest
    /// edge (never upscaling) and encodes it as PNG.
    private static func downscaledPNG(_ image: NSImage) -> Data? {
        let pixelSize = image.representations.reduce(CGSize.zero) { acc, rep in
            CGSize(width: max(acc.width, CGFloat(rep.pixelsWide)),
                   height: max(acc.height, CGFloat(rep.pixelsHigh)))
        }
        let source = pixelSize.width > 0 ? pixelSize : image.size
        guard source.width > 0, source.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(source.width, source.height))
        let target = CGSize(width: round(source.width * scale), height: round(source.height * scale))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = target

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }
}
