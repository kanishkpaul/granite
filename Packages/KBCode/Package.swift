// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBCode",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBCode", targets: ["KBCode"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
        .package(path: "../KBGit"),
    ],
    targets: [
        .target(name: "KBCode", dependencies: ["KBCore", "KBGit"]),
        .testTarget(name: "KBCodeTests", dependencies: ["KBCode", "KBGit"]),
    ],
    swiftLanguageModes: [.v6]
)
