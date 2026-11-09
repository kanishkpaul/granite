// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KBGit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KBGit", targets: ["KBGit"]),
    ],
    targets: [
        .target(name: "KBGit"),
        .testTarget(name: "KBGitTests", dependencies: ["KBGit"]),
    ],
    swiftLanguageModes: [.v6]
)
