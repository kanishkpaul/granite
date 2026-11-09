import ArgumentParser
import Foundation
import KBAI
import KBAIMLX
import KBCore
import KBIndex

@main
struct GraniteML: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "granite-ml",
        abstract: "Local embeddings, hybrid search and retrieval benchmarks (MLX).",
        subcommands: [Embed.self, Search.self, Bench.self, Ask.self, Generate.self]
    )
}

struct IndexOptions: ParsableArguments {
    @Option(help: "Vault folder.") var vault: String
    @Option(help: "index.sqlite path (default: the vault's Application Support index).") var db: String?

    var vaultValue: Vault { Vault(root: URL(filePath: (vault as NSString).expandingTildeInPath)) }
    var databaseURL: URL {
        db.map { URL(filePath: ($0 as NSString).expandingTildeInPath) }
            ?? vaultValue.supportDirectory.appending(path: "index.sqlite")
    }
}

func elapsedMs(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}

func log(_ text: String) { FileHandle.standardError.write(Data((text + "\n").utf8)) }

/// `GRANITE_RERANK_INSTRUCTION=default` uses the model's own instruction (for comparison).
func loadModels(reranker: Bool) async throws -> (MLXEmbedder, MLXReranker?) {
    let clock = ContinuousClock()
    var start = clock.now
    let embedder = try await MLXEmbedder.load()
    log(String(format: "embedder %@ loaded in %.1fs", embedder.modelID, elapsedMs(clock.now - start) / 1000))
    guard reranker else { return (embedder, nil) }
    start = clock.now
    let instruction = ProcessInfo.processInfo.environment["GRANITE_RERANK_INSTRUCTION"] == "default"
        ? nil : MLXReranker.notesInstruction
    let loaded = try await MLXReranker.load(instruction: instruction)
    log(String(format: "reranker %@ loaded in %.1fs", loaded.modelID, elapsedMs(clock.now - start) / 1000))
    return (embedder, loaded)
}

struct Embed: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Index the vault, then embed every chunk without a vector.")
    @OptionGroup var options: IndexOptions
    @Option(help: "Stop after this many chunks (for timing samples).") var limit: Int?
    @Option(help: "Chunks per model call.") var batch = 32

    func run() async throws {
        let database = try IndexDatabase(url: options.databaseURL)
        let indexer = Indexer(database: database, vault: options.vaultValue,
                              policy: try VaultPolicy.load(vaultRoot: options.vaultValue.root))
        log("index: \(try await indexer.reconcile())")
        let (embedder, _) = try await loadModels(reranker: false)
        let job = EmbeddingJob(database: database, embedder: embedder, batchSize: batch)
        log("pending chunks: \(try await job.pendingCount())")
        let report = try await job.run(limit: limit) { done, total in
            if done % 1024 < 32 || done == total { log("  \(done)/\(total)") }
        }
        print(report)
    }
}

struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Hybrid search: BM25 + vectors + RRF + rerank.")
    @OptionGroup var options: IndexOptions
    @Argument var query: [String]
    @Option(help: "bm25, vector or hybrid.") var mode = "hybrid"
    @Flag(help: "Skip the reranker.") var noRerank = false
    @Option var limit = 5
    @Option(help: "Abstain when the best rerank score is below this.") var abstain: Double?

    func run() async throws {
        let database = try IndexDatabase(url: options.databaseURL)
        let (embedder, reranker) = try await loadModels(reranker: !noRerank)
        let searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: embedder,
                                      reranker: reranker)
        var settings = HybridOptions()
        settings.mode = HybridOptions.Mode(rawValue: mode) ?? .hybrid
        settings.useReranker = !noRerank
        settings.limit = limit
        settings.abstainBelow = abstain
        let result = try await searcher.search(query.joined(separator: " "), options: settings)
        if result.abstained { print("I have no note on that.") }
        for hit in result.hits {
            let ranks = "bm25 \(hit.bm25Rank.map(String.init) ?? "-") · vec \(hit.vectorRank.map(String.init) ?? "-")"
                + (hit.rerankScore.map { String(format: " · rerank %.3f", $0) } ?? "")
            print("\(hit.path)  [\(ranks)]")
            if !hit.headingPath.isEmpty { print("  § \(hit.headingPath)") }
            print("  " + hit.text.prefix(160).replacingOccurrences(of: "\n", with: " "))
        }
        print(result.timings.sorted { $0.key < $1.key }.map { String(format: "%@ %.1fms", $0.key, $0.value) }
            .joined(separator: "  "))
    }
}

struct Bench: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Recall@5/10, MRR and latency for bm25, vector, hybrid and hybrid+rerank over a JSONL query set.")
    @OptionGroup var options: IndexOptions
    @Option(help: "JSONL of {query, expected} (default: <vault>/.granite/eval/synthetic.jsonl).") var queries: String?
    @Option(help: "Use at most this many queries.") var max = 100

    struct Query: Decodable { let query: String; let expected: String }

    func run() async throws {
        let database = try IndexDatabase(url: options.databaseURL)
        let path = queries.map { ($0 as NSString).expandingTildeInPath }
            ?? options.vaultValue.root.appending(path: ".granite/eval/synthetic.jsonl").path(percentEncoded: false)
        let set = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n").filter { !$0.isEmpty }
            .prefix(max).map { try JSONDecoder().decode(Query.self, from: Data($0.utf8)) }
        let (embedder, reranker) = try await loadModels(reranker: true)
        let searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: embedder,
                                      reranker: reranker)
        _ = try await searcher.search("warm up", options: HybridOptions())  // load vectors, compile kernels

        let variants: [(String, HybridOptions.Mode, Bool)] = [
            ("bm25", .bm25, false), ("vector", .vector, false), ("hybrid", .hybrid, false), ("hybrid+rerank", .hybrid, true),
        ]
        print("queries \(set.count)")
        for (name, mode, rerank) in variants {
            var settings = HybridOptions()
            settings.mode = mode
            settings.useReranker = rerank
            settings.includeAI = true
            var at5 = 0, at10 = 0
            var mrr = 0.0
            var latencies: [Double] = []
            var stages: [String: [Double]] = [:]
            for item in set {
                let clock = ContinuousClock()
                let start = clock.now
                let result = try await searcher.search(item.query, options: settings)
                latencies.append(elapsedMs(clock.now - start))
                for (stage, ms) in result.timings { stages[stage, default: []].append(ms) }
                if let rank = result.hits.firstIndex(where: { $0.path == item.expected }) {
                    if rank < 5 { at5 += 1 }
                    at10 += 1
                    mrr += 1 / Double(rank + 1)
                }
            }
            latencies.sort()
            let p = { (q: Double) in latencies[Swift.min(latencies.count - 1, Int(Double(latencies.count) * q))] }
            let n = Double(set.count)
            let stageText = stages.keys.sorted().filter { $0 != "total" }.map { key -> String in
                let values = stages[key, default: []].sorted()
                return String(format: "%@ p50 %.1f", key, values[values.count / 2])
            }.joined(separator: ", ")
            print(String(format: "%-14@ recall@5 %.3f  recall@10 %.3f  MRR %.3f  latency p50 %.0fms p95 %.0fms  (%@)",
                         name as NSString, Double(at5) / n, Double(at10) / n, mrr / n, p(0.5), p(0.95), stageText))
        }
    }
}

struct Ask: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Grounded Q&A: answer only from the vault, every sentence verified.")
    @OptionGroup var options: IndexOptions
    @Argument var question: [String]
    @Option(help: "Your own view first (Socratic mode).") var view: String?
    @Option(help: "Also offer the local MLX route with this model (Hugging Face id; downloaded once).") var mlx: String?

    func run() async throws {
        let database = try IndexDatabase(url: options.databaseURL)
        let (embedder, reranker) = try await loadModels(reranker: true)
        let searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: embedder,
                                      reranker: reranker)
        var providers = ModelService.standardProviders()
        if let mlx {
            let provider = MLXLanguageProvider(modelID: mlx)
            try await provider.load()
            providers.append(provider)
        }
        let models = ModelService(providers: providers, state: nil)
        let qa = GroundedQA(models: models, retrieve: GroundedQA.retrieval(searcher))
        let clock = ContinuousClock()
        let start = clock.now
        let answer = try await qa.ask(question.joined(separator: " "), mode: view == nil ? .tellMe : .socratic, userView: view)
        let ms = elapsedMs(clock.now - start)
        if answer.abstained {
            print("I have no note on that.")
        }
        for sentence in answer.sentences {
            let source = sentence.sourceID.flatMap { id in answer.sources.first { $0.id == id } }
            let where_ = source.map { "\($0.hit.path):\($0.hit.startLine)" } ?? "no source"
            print("\(sentence.verified ? "✓" : "✗ unsupported") \(sentence.text)  [\(where_)]")
        }
        print(String(format: "route %@ · label %@ · %d/%d verified · %.0f ms%@", answer.route?.rawValue ?? "none",
                     answer.label.rawValue, answer.verifiedCount, answer.sentences.count, ms,
                     answer.notice.map { " · " + $0 } ?? ""))
    }
}


struct Generate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Smoke-test the local MLX language model route.")
    @Option(help: "Hugging Face model id.") var model = MLXLanguageProvider.defaultModel
    @Flag(help: "Ask for JSON {\"answer\": string} and decode it.") var json = false
    @Argument var prompt: [String]

    func run() async throws {
        let provider = MLXLanguageProvider(modelID: model)
        let clock = ContinuousClock()
        var start = clock.now
        try await provider.load { progress in
            FileHandle.standardError.write(Data("\rdownloading \(Int(progress.fractionCompleted * 100))%".utf8))
        }
        print(String(format: "loaded %@ in %.1f s", model, elapsedMs(clock.now - start) / 1000))
        start = clock.now
        let schema: OutputSchema? = json ? .object(name: "Reply", fields: [.init("answer", .string("one sentence"))]) : nil
        let generation = try await provider.generate(GenerationRequest(system: "You are concise.", prompt: prompt.joined(separator: " "),
                                                                       schema: schema, maxTokens: 200))
        print(generation.text)
        if json { print("decoded:", (try? generation.decode([String: String].self))?["answer"] ?? "✗ not JSON") }
        print(String(format: "%.1f s", elapsedMs(clock.now - start) / 1000))
    }
}
