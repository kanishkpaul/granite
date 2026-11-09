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
    ],
    targets: [
        .target(name: "KBCapture", dependencies: ["KBCore"]),
        .testTarget(name: "KBCaptureTests", dependencies: ["KBCapture"]),
    ],
    swiftLanguageModes: [.v6]
)
