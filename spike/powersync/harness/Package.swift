// swift-tools-version: 6.2
import PackageDescription

// ADR-0004 spike harness. Throwaway code: proves (or disproves) PowerSync for Relo.
// Built in Swift 6 language mode with complete concurrency checking (exit criterion 1),
// alongside the app's own RelocKit package.
let package = Package(
    name: "SyncSpike",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/powersync-ja/powersync-swift", from: "1.17.0"),
        .package(path: "../../../apps/ios/Packages/RelocKit"),
    ],
    targets: [
        .executableTarget(
            name: "SyncSpike",
            dependencies: [
                .product(name: "PowerSync", package: "powersync-swift"),
                .product(name: "RelocDomain", package: "RelocKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
