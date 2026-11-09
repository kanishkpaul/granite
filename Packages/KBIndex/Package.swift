// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBIndex",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBIndex", targets: ["KBIndex"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
        .package(path: "../KBTestSupport"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.12.0"),
    ],
    targets: [
        .target(
            name: "KBIndex",
            dependencies: ["KBCore", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "KBIndexTests",
            dependencies: ["KBIndex", "KBTestSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
