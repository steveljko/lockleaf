// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lockleaf",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "TOTPCore", targets: ["TOTPCore"]),
        .library(name: "KeychainStore", targets: ["KeychainStore"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "VaultKit", targets: ["VaultKit"]),
        .library(name: "BackupKit", targets: ["BackupKit"]),
        .library(name: "DomainServices", targets: ["DomainServices"]),
        .executable(name: "Lockleaf", targets: ["LockleafApp"]),
    ],
    targets: [
        // MARK: - Domain entities and value types (no platform dependencies)
        .target(
            name: "CoreModels",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - RFC 6238 / 4226 engine and otpauth:// parsing
        .target(
            name: "TOTPCore",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Keychain Services wrapper (Security framework)
        .target(
            name: "KeychainStore",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SQLite metadata store (system SQLite3)
        .target(
            name: "Persistence",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - LocalAuthentication vault, clipboard, settings
        .target(
            name: "VaultKit",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Encrypted backup import/export
        .target(
            name: "BackupKit",
            dependencies: ["CoreModels", "TOTPCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Use cases / orchestration / dependency container
        .target(
            name: "DomainServices",
            dependencies: [
                "CoreModels", "TOTPCore", "KeychainStore",
                "Persistence", "VaultKit", "BackupKit",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SwiftUI application
        .executableTarget(
            name: "LockleafApp",
            dependencies: ["DomainServices"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Tests
        .testTarget(name: "TOTPCoreTests", dependencies: ["TOTPCore"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .testTarget(name: "BackupKitTests", dependencies: ["BackupKit"]),
        .testTarget(name: "KeychainStoreTests", dependencies: ["KeychainStore"]),
        .testTarget(name: "DomainServicesTests", dependencies: ["DomainServices"]),
    ]
)
