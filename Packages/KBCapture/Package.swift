// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBCapture",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBCapture", targets: ["KBCapture"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
        .package(path: "../KBIndex"),
    ],
    targets: [
        .target(name: "KBCapture", dependencies: ["KBCore", "KBIndex"]),
        .testTarget(name: "KBCaptureTests", dependencies: ["KBCapture", "KBIndex"]),
    ],
    swiftLanguageModes: [.v6]
)
