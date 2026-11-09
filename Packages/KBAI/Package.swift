// swift-tools-version: 6.2
import PackageDescription

// The only package (besides the app) allowed to import FoundationModels or MLX. macOS 27+.
let package = Package(
    name: "KBAI",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "KBAI", targets: ["KBAI"]),
    ],
    targets: [
        .target(name: "KBAI"),
        .testTarget(name: "KBAITests", dependencies: ["KBAI"]),
    ],
    swiftLanguageModes: [.v6]
)
