import Foundation

/// How an entry or group renders its circular avatar. No image bytes live here;
/// uploaded images are referenced by a file name inside the app's
/// Application Support container so the database stays small.
public enum Avatar: Codable, Sendable, Hashable {
    /// Auto-generated initials over a deterministic color derived from the name.
    case initials
    /// A single emoji glyph.
    case emoji(String)
    /// A user-supplied image stored on disk, referenced by file name.
    case image(fileName: String)
    /// A symbol from SF Symbols.
    case symbol(name: String)

    public static let `default` = Avatar.initials
}

/// A small, curated palette so groups/entries look cohesive and native.
public enum AccentColor: String, Codable, Sendable, CaseIterable, Hashable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, gray

    public static let `default` = AccentColor.blue
}
