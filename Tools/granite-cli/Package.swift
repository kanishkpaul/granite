// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "granite-cli",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "granite-cli", targets: ["granite-cli"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KBCore"),
        .package(path: "../../Packages/KBIndex"),
        .package(path: "../../Packages/KBTestSupport"),
        .package(path: "../../Packages/KBAI"),
        .package(path: "../../Packages/KBGit"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "granite-cli",
            dependencies: [
                "KBCore", "KBIndex", "KBTestSupport", "KBAI", "KBGit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
