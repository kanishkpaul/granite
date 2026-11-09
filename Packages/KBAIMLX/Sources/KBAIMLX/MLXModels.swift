import Foundation
import HuggingFace
import KBIndex
import MLX
import MLXEmbedders
import MLXHuggingFace
import MLXLMCommon
import MLXRerankers
import Tokenizers

/// Default local models (master plan §6.1). Downloaded once into the Hugging Face cache.
public enum LocalModels {
    /// EmbeddingGemma 300M, 8-bit (366 MB).
    public static let embedder = "mlx-community/embeddinggemma-300m-8bit"
    /// Qwen3-Reranker 0.6B, 4-bit (347 MB).
    public static let reranker = "mlx-community/Qwen3-Reranker-0.6B-4bit"
}

/// EmbeddingGemma through MLX, truncated Matryoshka-style to `dimension` (768 → 512 by default).
public final class MLXEmbedder: Embedder {
    public let modelID: String
    public let dimension: Int
    let maxTokens: Int
    private let container: EmbedderModelContainer

    private init(modelID: String, dimension: Int, maxTokens: Int, container: EmbedderModelContainer) {
        self.modelID = modelID
        self.dimension = dimension
        self.maxTokens = maxTokens
        self.container = container
    }

    public static func load(id: String = LocalModels.embedder, dimension: Int = 512, maxTokens: Int = 1024,
                            progress: @Sendable @escaping (Progress) -> Void = { _ in }) async throws -> MLXEmbedder {
        let container = try await EmbedderModelFactory.shared.loadContainer(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(id: id),
            progressHandler: progress
        )
        return MLXEmbedder(modelID: "\(id)@\(dimension)", dimension: dimension, maxTokens: maxTokens, container: container)
    }

    // EmbeddingGemma's retrieval prompts (model card): queries and documents are framed differently.
    public func embed(documents: [String]) async throws -> [[Float]] {
        try await run(documents.map { "title: none | text: \($0)" })
    }

    public func embed(query: String) async throws -> [Float] {
        try await run(["task: search result | query: \(query)"])[0]
    }

    private func run(_ texts: [String]) async throws -> [[Float]] {
        let maxTokens = self.maxTokens
        let dimension = self.dimension
        let full = await container.perform { context -> [[Float]] in
            let inputs = texts.map { Array(context.tokenizer.encode(text: $0, addSpecialTokens: true).prefix(maxTokens)) }
            let longest = inputs.reduce(1) { max($0, $1.count) }
            let pad = context.tokenizer.eosTokenId ?? 0
            let padded = stacked(inputs.map { MLXArray($0 + Array(repeating: pad, count: longest - $0.count)) })
            let mask = stacked(inputs.map {
                MLXArray(Array(repeating: true, count: $0.count) + Array(repeating: false, count: longest - $0.count))
            })
            let output = context.pooling(
                context.model(padded, positionIds: nil, tokenTypeIds: MLXArray.zeros(like: padded), attentionMask: mask),
                normalize: true, applyLayerNorm: true)
            output.eval()
            return output.map { $0.asArray(Float.self) }
        }
        // Matryoshka: keep the first `dimension` components; KBIndex renormalizes.
        return full.map { Array($0.prefix(dimension)) }
    }
}

/// Qwen3-Reranker through MLX. Scores are normalized relevance in 0…1.
public final class MLXReranker: KBIndex.Reranker {
    /// Qwen3-Reranker's default instruction targets web passages that *answer* a query; personal
    /// notes are often relevant without answering. Override with `instruction: nil` to compare.
    public static let notesInstruction =
        "Given a question about the user's personal notes, judge whether this note contains information relevant to it"

    public let modelID: String
    public let instruction: String?
    private let container: RerankerContainer

    private init(modelID: String, instruction: String?, container: RerankerContainer) {
        self.modelID = modelID
        self.instruction = instruction
        self.container = container
    }

    public static func load(id: String = LocalModels.reranker, instruction: String? = notesInstruction,
                            progress: @Sendable @escaping (Progress) -> Void = { _ in }) async throws -> MLXReranker {
        let container = try await RerankerModelFactory.shared.loadContainer(
            from: #hubDownloader(), using: #huggingFaceTokenizerLoader(), id: id, progressHandler: progress)
        return MLXReranker(modelID: id, instruction: instruction, container: container)
    }

    public func scores(query: String, documents: [String]) async throws -> [Double] {
        let response = try await container.scores(query: query, documents: documents, instruction: instruction)
        var scores = [Double](repeating: 0, count: documents.count)
        for result in response.results where result.index < scores.count { scores[result.index] = result.score }
        return scores
    }
}
