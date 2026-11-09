// swift-tools-version: 6.2
import PackageDescription

// MLX-backed Embedder and Reranker for KBIndex's hybrid search, and the opt-in local language
// model route for KBAI.
// Build and run with xcodebuild, not `swift build`: SwiftPM cannot compile MLX's Metal shaders.
let package = Package(
    name: "KBAIMLX",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "KBAIMLX", targets: ["KBAIMLX"]),
    ],
    dependencies: [
        .package(path: "../KBIndex"),
        .package(path: "../KBAI"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.32.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "KBAIMLX",
            dependencies: [
                "KBIndex",
                "KBAI",
                .product(name: "MLXEmbedders", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXRerankers", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
