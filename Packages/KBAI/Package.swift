// swift-tools-version: 6.2
import PackageDescription

// The model layer: routing, providers (Apple on-device, PCC, Claude), audit, budget.
// Only this package, KBAIMLX and the app may import FoundationModels or MLX. macOS 27+.
let package = Package(
    name: "KBAI",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "KBAI", targets: ["KBAI"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
        .package(path: "../KBIndex"),
        .package(path: "../KBReview"),
    ],
    targets: [
        .target(name: "KBAI", dependencies: ["KBCore", "KBIndex", "KBReview"]),
        .testTarget(name: "KBAITests", dependencies: ["KBAI"]),
    ],
    swiftLanguageModes: [.v6]
)
