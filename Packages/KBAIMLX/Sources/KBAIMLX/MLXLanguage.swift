import Foundation
import HuggingFace
import KBAI
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// The `mlx` route (master plan §6.1): an open-weight model running in-process with MLX, for
/// `local` and `pcc` notes when the on-device model is too small, and for overnight jobs.
/// Opt-in: it is only available once you turn it on and its weights are downloaded (Settings → AI).
public actor MLXLanguageProvider: LanguageProvider {
    public nonisolated let route: ModelRoute = .mlx
    public nonisolated let modelID: String
    private let isEnabled: @Sendable () -> Bool
    private var container: ModelContainer?
    private var loading: Task<ModelContainer, any Error>?

    /// Choices offered in Settings, smallest first. Sizes are the 4-bit downloads.
    public static let choices: [(id: String, label: String)] = [
        ("mlx-community/Qwen3-4B-4bit", "Qwen3 4B (2.3 GB)"),
        ("mlx-community/gemma-4-e4b-it-4bit", "Gemma 4 E4B (3 GB)"),
        ("mlx-community/Qwen3-8B-4bit", "Qwen3 8B (4.6 GB)"),
    ]
    public static let defaultModel = "mlx-community/Qwen3-8B-4bit"

    public init(modelID: String = MLXLanguageProvider.defaultModel, isEnabled: @escaping @Sendable () -> Bool = { true }) {
        self.modelID = modelID
        self.isEnabled = isEnabled
    }

    /// Available only when turned on and already downloaded: a request never starts a multi-GB download.
    public func isAvailable() async -> Bool {
        isEnabled() && Self.isDownloaded(modelID)
    }

    /// Downloads (once, into the Hugging Face cache) and loads the weights.
    @discardableResult
    public func load(progress: @Sendable @escaping (Progress) -> Void = { _ in }) async throws -> ModelContainer {
        if let container { return container }
        if let loading { return try await loading.value }
        let id = modelID
        let task = Task {
            try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(), using: #huggingFaceTokenizerLoader(),
                configuration: ModelConfiguration(id: id), progressHandler: progress)
        }
        loading = task
        defer { loading = nil }
        let loaded = try await task.value
        container = loaded
        return loaded
    }

    public func generate(_ request: GenerationRequest) async throws -> KBAI.Generation {
        guard isEnabled() else { throw ModelError.unavailable("the local MLX model is turned off") }
        let model: ModelContainer
        do {
            model = try await load()
        } catch {
            throw ModelError.unavailable("MLX model \(modelID): \(ModelError.brief(error))")
        }
        var system = request.system
        // No guided generation here: describe the JSON and extract it from the reply.
        if let schema = request.schema { system += "\n\n" + schema.promptHint }
        var prompt = request.promptWithDocuments
        if Self.isQwen3(modelID) { prompt += "\n/no_think" }
        let session = ChatSession(model, instructions: system,
                                  generateParameters: GenerateParameters(maxTokens: request.maxTokens, temperature: 0.3))
        let raw: String
        do {
            raw = try await session.respond(to: prompt)
        } catch {
            throw ModelError.unavailable("MLX generation failed: \(ModelError.brief(error))")
        }
        let text = Self.stripThinking(raw)
        guard !text.isEmpty else { throw ModelError.badResponse("empty reply from \(modelID)") }
        return KBAI.Generation(text: text, inputTokens: (system.count + prompt.count) / 4, outputTokens: raw.count / 4, model: modelID)
    }

    static func isQwen3(_ id: String) -> Bool { id.lowercased().contains("qwen3") }

    /// Qwen3 can emit a `<think>…</think>` block before the answer; the answer is what follows it.
    public static func stripThinking(_ text: String) -> String {
        var output = text
        while let start = output.range(of: "<think>") {
            if let end = output.range(of: "</think>", range: start.upperBound..<output.endIndex) {
                output.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                output.removeSubrange(start.lowerBound..<output.endIndex)
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the weights are in the Hugging Face cache (`~/.cache/huggingface/hub`).
    public static func isDownloaded(_ id: String) -> Bool {
        let base = ProcessInfo.processInfo.environment["HF_HUB_CACHE"].map { URL(filePath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cache/huggingface/hub")
        let snapshots = base.appending(path: "models--" + id.replacingOccurrences(of: "/", with: "--")).appending(path: "snapshots")
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: snapshots.path(percentEncoded: false)) else { return false }
        return versions.contains { version in
            let folder = snapshots.appending(path: version)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
            return files.contains("config.json") && files.contains { $0.hasSuffix(".safetensors") }
        }
    }
}
