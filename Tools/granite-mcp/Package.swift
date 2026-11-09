// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "granite-mcp",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "granite-mcp", targets: ["granite-mcp"]),
        .library(name: "GraniteMCPKit", targets: ["GraniteMCPKit"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KBCore"),
        .package(path: "../../Packages/KBIndex"),
        .package(path: "../../Packages/KBTestSupport"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1"),
    ],
    targets: [
        .target(
            name: "GraniteMCPKit",
            dependencies: ["KBCore", "KBIndex", .product(name: "MCP", package: "swift-sdk")]
        ),
        .executableTarget(name: "granite-mcp", dependencies: ["GraniteMCPKit"]),
        .testTarget(name: "GraniteMCPKitTests", dependencies: ["GraniteMCPKit", "KBTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
