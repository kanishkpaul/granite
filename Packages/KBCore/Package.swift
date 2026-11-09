// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBCore", targets: ["KBCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
    ],
    targets: [
        .target(
            name: "KBCore",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .testTarget(
            name: "KBCoreTests",
            dependencies: ["KBCore"],
            resources: [.copy("Golden")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
