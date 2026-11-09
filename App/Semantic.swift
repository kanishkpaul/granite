import Foundation
import KBAIMLX
import KBIndex

/// Local semantic search for the app: loads EmbeddingGemma (and later the reranker) on demand,
/// keeps every chunk embedded in the background, and serves hybrid search.
@MainActor
@Observable
final class SemanticEngine {
    static let enabledKey = "granite.semantic"

    private(set) var status: String?
    private(set) var searcher: HybridSearcher?
    private(set) var reranker: MLXReranker?
    private var embedder: MLXEmbedder?
    private var database: IndexDatabase?
    private var embedding: Task<Void, Never>?
    private var rerun = false
    private var loadingReranker: Task<MLXReranker?, Never>?

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if newValue, let database { start(database: database) } else { stop() }
        }
    }

    /// Called when a vault opens. Loads (downloading once, ~0.4 GB) the embedder, then embeds.
    func start(database: IndexDatabase) {
        self.database = database
        guard isEnabled else { return }
        if embedder != nil {
            searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: embedder,
                                      reranker: reranker)
            scheduleEmbedding()
            return
        }
        status = "Loading the search model…"
        Task {
            do {
                let loaded = try await MLXEmbedder.load { progress in
                    let percent = Int(progress.fractionCompleted * 100)
                    Task { @MainActor in self.status = "Downloading the search model… \(percent)%" }
                }
                embedder = loaded
                searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: loaded,
                                          reranker: reranker)
                status = nil
                scheduleEmbedding()
            } catch {
                status = "Semantic search unavailable: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        embedding?.cancel()
        embedding = nil
        searcher = nil
        status = nil
    }

    /// Embeds whatever has no vector yet. Coalesces: one job at a time, rerun if asked meanwhile.
    func scheduleEmbedding() {
        guard let embedder, let database, isEnabled else { return }
        if embedding != nil {
            rerun = true
            return
        }
        embedding = Task {
            let job = EmbeddingJob(database: database, embedder: embedder)
            repeat {
                rerun = false
                let pending = (try? await job.pendingCount()) ?? 0
                if pending > 0 {
                    status = "Embedding \(pending) passage(s) for search…"
                    _ = try? await job.run { done, total in
                        Task { @MainActor in self.status = "Embedding for search: \(done) of \(total)" }
                    }
                }
            } while rerun && !Task.isCancelled
            status = nil
            embedding = nil
        }
    }

    /// The reranker for grounded answers, loaded (downloading once, ~0.35 GB) the first time it's needed.
    func loadReranker() async -> MLXReranker? {
        if let reranker { return reranker }
        if let loadingReranker { return await loadingReranker.value }
        let task = Task { () -> MLXReranker? in
            status = "Loading the answer model…"
            let loaded = try? await MLXReranker.load()
            status = nil
            return loaded
        }
        loadingReranker = task
        let loaded = await task.value
        reranker = loaded
        loadingReranker = nil
        if let database, let embedder {
            searcher = HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: embedder,
                                      reranker: loaded)
        }
        return loaded
    }

    var hasVectors: Bool {
        guard let database else { return false }
        return ((try? database.pool.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM chunk_vectors") }) ?? 0) > 0
    }
}
