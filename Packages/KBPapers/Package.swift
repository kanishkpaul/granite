// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBPapers",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBPapers", targets: ["KBPapers"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
    ],
    targets: [
        .target(name: "KBPapers", dependencies: ["KBCore"]),
        .testTarget(name: "KBPapersTests", dependencies: ["KBPapers"]),
    ],
    swiftLanguageModes: [.v6]
)
