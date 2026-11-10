// swift-tools-version: 6.2
import PackageDescription

// RelocKit holds the app's modules as separate library targets so domain logic
// can be built and tested with `swift test` on a Mac, without a simulator.
let package = Package(
    name: "RelocKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "RelocDomain", targets: ["RelocDomain"]),
    ],
    targets: [
        // Pure Swift: models and business rules. No UI, networking, or persistence.
        .target(name: "RelocDomain"),
        .testTarget(name: "RelocDomainTests", dependencies: ["RelocDomain"]),
    ],
    swiftLanguageModes: [.v6]
)
