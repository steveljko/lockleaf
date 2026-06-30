import CoreModels
import Foundation

/// Offline mapping from a service name to a recognizable icon + color.
///
/// We deliberately do **not** fetch logos from the network (that would leak which
/// services a user has and violate the app's no-network stance). Instead we ship
/// a curated catalog of SF Symbols and brand-ish colors, matched by keyword, so
/// well-known issuers look distinct out of the box while everything stays local.
enum BrandCatalog {
    struct Brand {
        let symbol: String
        let color: AccentColor
    }

    /// Keyword → brand. First substring match wins, so order longer/more specific
    /// keywords before generic ones.
    private static let table: [(keyword: String, brand: Brand)] = [
        ("github", .init(symbol: "chevron.left.forwardslash.chevron.right", color: .purple)),
        ("gitlab", .init(symbol: "chevron.left.forwardslash.chevron.right", color: .orange)),
        ("bitbucket", .init(symbol: "chevron.left.forwardslash.chevron.right", color: .blue)),
        ("aws", .init(symbol: "server.rack", color: .orange)),
        ("amazon", .init(symbol: "cart.fill", color: .orange)),
        ("apple", .init(symbol: "apple.logo", color: .gray)),
        ("icloud", .init(symbol: "cloud.fill", color: .blue)),
        ("microsoft", .init(symbol: "square.grid.2x2.fill", color: .blue)),
        ("azure", .init(symbol: "cloud.fill", color: .blue)),
        ("office", .init(symbol: "doc.fill", color: .red)),
        ("google", .init(symbol: "magnifyingglass.circle.fill", color: .blue)),
        ("gmail", .init(symbol: "envelope.fill", color: .red)),
        ("youtube", .init(symbol: "play.rectangle.fill", color: .red)),
        ("facebook", .init(symbol: "person.2.fill", color: .blue)),
        ("meta", .init(symbol: "infinity", color: .blue)),
        ("instagram", .init(symbol: "camera.fill", color: .pink)),
        ("whatsapp", .init(symbol: "phone.fill", color: .green)),
        ("twitter", .init(symbol: "bird.fill", color: .cyan)),
        ("discord", .init(symbol: "message.fill", color: .indigo)),
        ("slack", .init(symbol: "number.square.fill", color: .purple)),
        ("telegram", .init(symbol: "paperplane.fill", color: .cyan)),
        ("dropbox", .init(symbol: "shippingbox.fill", color: .blue)),
        ("paypal", .init(symbol: "dollarsign.circle.fill", color: .blue)),
        ("stripe", .init(symbol: "creditcard.fill", color: .indigo)),
        ("coinbase", .init(symbol: "bitcoinsign.circle.fill", color: .blue)),
        ("binance", .init(symbol: "bitcoinsign.circle.fill", color: .yellow)),
        ("kraken", .init(symbol: "bitcoinsign.circle.fill", color: .purple)),
        ("bitcoin", .init(symbol: "bitcoinsign.circle.fill", color: .orange)),
        ("crypto", .init(symbol: "bitcoinsign.circle.fill", color: .teal)),
        ("steam", .init(symbol: "gamecontroller.fill", color: .blue)),
        ("twitch", .init(symbol: "play.tv.fill", color: .purple)),
        ("epic", .init(symbol: "gamecontroller.fill", color: .gray)),
        ("playstation", .init(symbol: "gamecontroller.fill", color: .blue)),
        ("nintendo", .init(symbol: "gamecontroller.fill", color: .red)),
        ("reddit", .init(symbol: "antenna.radiowaves.left.and.right", color: .orange)),
        ("linkedin", .init(symbol: "briefcase.fill", color: .blue)),
        ("netflix", .init(symbol: "play.rectangle.fill", color: .red)),
        ("spotify", .init(symbol: "music.note", color: .green)),
        ("cloudflare", .init(symbol: "cloud.fill", color: .orange)),
        ("digitalocean", .init(symbol: "drop.fill", color: .blue)),
        ("heroku", .init(symbol: "cloud.fill", color: .purple)),
        ("npm", .init(symbol: "shippingbox.fill", color: .red)),
        ("docker", .init(symbol: "shippingbox.fill", color: .blue)),
        ("ssh", .init(symbol: "terminal.fill", color: .green)),
        ("server", .init(symbol: "server.rack", color: .teal)),
        ("vpn", .init(symbol: "network.badge.shield.half.filled", color: .green)),
        ("bank", .init(symbol: "building.columns.fill", color: .green)),
        ("mail", .init(symbol: "envelope.fill", color: .blue)),
        ("proton", .init(symbol: "lock.fill", color: .purple)),
    ]

    /// Returns a brand for the given issuer/name, or `nil` if nothing matches.
    static func match(_ text: String) -> Brand? {
        let needle = text.lowercased()
        guard !needle.isEmpty else { return nil }
        return table.first { needle.contains($0.keyword) }?.brand
    }
}
