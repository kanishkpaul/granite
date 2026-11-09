// swift-tools-version: 6.2
import PackageDescription

// Embedding, hybrid search and benchmarks with local MLX models.
// Build with xcodebuild (SwiftPM cannot compile MLX's Metal shaders):
//   xcodebuild -scheme granite-ml -destination 'platform=macOS' -derivedDataPath .build/xcode build
let package = Package(
    name: "granite-ml",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(path: "../../Packages/KBCore"),
        .package(path: "../../Packages/KBIndex"),
        .package(path: "../../Packages/KBAIMLX"),
        .package(path: "../../Packages/KBAI"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "granite-ml",
            dependencies: [
                "KBCore", "KBIndex", "KBAIMLX", "KBAI",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
