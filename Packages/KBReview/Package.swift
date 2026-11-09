// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBReview",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBReview", targets: ["KBReview"]),
    ],
    dependencies: [
        .package(path: "../KBCore"),
        .package(path: "../KBIndex"),
    ],
    targets: [
        .target(name: "KBReview", dependencies: ["KBCore", "KBIndex"]),
        .testTarget(name: "KBReviewTests", dependencies: ["KBReview", "KBIndex"]),
    ],
    swiftLanguageModes: [.v6]
)
