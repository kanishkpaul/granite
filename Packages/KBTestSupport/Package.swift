// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBTestSupport",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBTestSupport", targets: ["KBTestSupport"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
    ],
    targets: [
        .target(name: "KBTestSupport", dependencies: ["KBCore"]),
        .testTarget(name: "KBTestSupportTests", dependencies: ["KBTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
