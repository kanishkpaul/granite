import Accelerate
import Foundation
import GRDB
import KBCore

/// Turns text into vectors. The MLX implementation lives in `KBAIMLX`; tests use a fake.
public protocol Embedder: Sendable {
    /// Stored with the vectors; a different id means every vector is recomputed.
    var modelID: String { get }
    /// Length of the vectors returned (after any Matryoshka truncation).
    var dimension: Int { get }
    func embed(documents: [String]) async throws -> [[Float]]
    func embed(query: String) async throws -> [Float]
}

/// Scores query–passage relevance. Higher is more relevant; scores are in 0…1.
public protocol Reranker: Sendable {
    var modelID: String { get }
    func scores(query: String, documents: [String]) async throws -> [Double]
}

public struct EmbedReport: Sendable, CustomStringConvertible {
    public var embedded = 0
    public var cleared = 0
    public var seconds = 0.0
    public var chunksPerSecond: Double { seconds > 0 ? Double(embedded) / seconds : 0 }

    public var description: String {
        String(format: "embedded %d chunks in %.1fs (%.1f chunks/s)", embedded, seconds, chunksPerSecond)
            + (cleared > 0 ? ", cleared \(cleared) stale vectors" : "")
    }
}

/// Embeds every chunk that has no vector yet. Notes labelled `none` are never embedded
/// (master plan §6.1). Safe to run repeatedly: it only does the missing work.
public actor EmbeddingJob {
    public let database: IndexDatabase
    public let embedder: any Embedder
    let batchSize: Int

    public init(database: IndexDatabase, embedder: any Embedder, batchSize: Int = 32) {
        self.database = database
        self.embedder = embedder
        self.batchSize = batchSize
    }

    public func run(limit: Int? = nil, progress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> EmbedReport {
        let clock = ContinuousClock()
        let start = clock.now
        var report = EmbedReport()
        report.cleared = try resetIfModelChanged()
        let total = try pendingCount()
        let goal = min(total, limit ?? total)
        while report.embedded < goal {
            // Take a window of pending chunks and batch them by length: a batch is padded to its
            // longest member, so mixing short and long chunks wastes most of the compute.
            let window = try pending(limit: min(batchSize * 16, goal - report.embedded))
                .sorted { $0.text.utf8.count < $1.text.utf8.count }
            if window.isEmpty { break }
            for start in stride(from: 0, to: window.count, by: batchSize) {
                let batch = Array(window[start..<min(start + batchSize, window.count)])
                let vectors = try await embedder.embed(documents: batch.map(\.text))
                guard vectors.count == batch.count else {
                    throw EmbeddingError.countMismatch(expected: batch.count, got: vectors.count)
                }
                try await database.pool.write { db in
                    let insert = try db.cachedStatement(sql: "INSERT OR REPLACE INTO chunk_vectors(chunk, vector) VALUES (?, ?)")
                    for (item, vector) in zip(batch, vectors) {
                        try insert.execute(arguments: [item.id, VectorMath.blob(VectorMath.normalized(vector))])
                    }
                    try db.execute(sql: """
                        INSERT INTO meta(key, value) VALUES ('vectors.generation', '1')
                        ON CONFLICT(key) DO UPDATE SET value = CAST(value AS INTEGER) + 1
                        """)
                }
                report.embedded += batch.count
                progress?(report.embedded, goal)
            }
        }
        report.seconds = Double((clock.now - start).components.seconds)
            + Double((clock.now - start).components.attoseconds) / 1e18
        return report
    }

    /// Chunks still waiting for a vector.
    public func pendingCount() throws -> Int {
        try database.pool.read { db in
            try Int.fetchOne(db, sql: """
                SELECT count(*) FROM chunks c JOIN objects o ON o.rowid = c.obj
                LEFT JOIN chunk_vectors v ON v.chunk = c.id
                WHERE v.chunk IS NULL AND o.ai_label != 'none'
                """) ?? 0
        }
    }

    struct Pending: Sendable {
        let id: Int64
        let text: String
    }

    func pending(limit: Int) throws -> [Pending] {
        try database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT c.id, c.prefix || char(10) || c.text AS text FROM chunks c JOIN objects o ON o.rowid = c.obj
                LEFT JOIN chunk_vectors v ON v.chunk = c.id
                WHERE v.chunk IS NULL AND o.ai_label != 'none'
                ORDER BY c.id LIMIT ?
                """, arguments: [limit])
            .map { Pending(id: $0["id"], text: $0["text"]) }
        }
    }

    /// Vectors from another model, dimension or chunker version are deleted, never mixed.
    func resetIfModelChanged() throws -> Int {
        try database.pool.write { db in
            let row = try Row.fetchOne(db, sql: "SELECT model_id, dim, chunker_version FROM embed_meta WHERE id = 1")
            let matches = row.map {
                ($0["model_id"] as String) == embedder.modelID && ($0["dim"] as Int) == embedder.dimension
                    && ($0["chunker_version"] as Int) == Chunker.version
            } ?? false
            guard !matches else { return 0 }
            let cleared = try Int.fetchOne(db, sql: "SELECT count(*) FROM chunk_vectors") ?? 0
            try db.execute(sql: "DELETE FROM chunk_vectors")
            try db.execute(sql: "INSERT OR REPLACE INTO embed_meta(id, model_id, dim, chunker_version) VALUES (1, ?, ?, ?)",
                           arguments: [embedder.modelID, embedder.dimension, Chunker.version])
            return cleared
        }
    }
}

public enum EmbeddingError: Error, CustomStringConvertible {
    case countMismatch(expected: Int, got: Int)
    case dimensionMismatch(expected: Int, got: Int)

    public var description: String {
        switch self {
        case .countMismatch(let expected, let got): "embedder returned \(got) vectors for \(expected) texts"
        case .dimensionMismatch(let expected, let got): "vector has \(got) dimensions, index expects \(expected)"
        }
    }
}

public enum VectorMath {
    public static func normalized(_ vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = norm.squareRoot()
        guard norm > 0 else { return vector }
        var scale = 1 / norm
        var result = [Float](repeating: 0, count: vector.count)
        vDSP_vsmul(vector, 1, &scale, &result, 1, vDSP_Length(vector.count))
        return result
    }

    public static func blob(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func vector(_ blob: Data) -> [Float] {
        blob.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

/// Exact nearest neighbours by cosine over every stored vector (master plan §3's fallback for
/// sqlite-vec: milliseconds below ~200k chunks). Reloads when the vector generation changes.
public actor VectorIndex {
    public let database: IndexDatabase
    private var ids: [Int64] = []
    private var matrix: [Float] = []
    private var dimension = 0
    private var generation: String?

    public init(database: IndexDatabase) {
        self.database = database
    }

    public var count: Int { ids.count }

    /// Top `k` chunk ids by cosine similarity to `query` (normalized inside).
    public func nearest(_ query: [Float], k: Int) throws -> [(chunk: Int64, score: Float)] {
        try reloadIfNeeded()
        guard !ids.isEmpty else { return [] }
        guard query.count == dimension else {
            throw EmbeddingError.dimensionMismatch(expected: dimension, got: query.count)
        }
        let q = VectorMath.normalized(query)
        var scores = [Float](repeating: 0, count: ids.count)
        // (n × d) · (d × 1): one matrix–vector product for every stored vector at once.
        vDSP_mmul(matrix, 1, q, 1, &scores, 1, vDSP_Length(ids.count), 1, vDSP_Length(dimension))
        let top = min(k, ids.count)
        // Partial selection: keep a small sorted buffer instead of sorting every score.
        var best: [(chunk: Int64, score: Float)] = []
        best.reserveCapacity(top + 1)
        for (index, score) in scores.enumerated() {
            if best.count < top || score > (best.last?.score ?? -.infinity) {
                let position = best.firstIndex { $0.score < score } ?? best.count
                best.insert((ids[index], score), at: position)
                if best.count > top { best.removeLast() }
            }
        }
        return best
    }

    private func reloadIfNeeded() throws {
        let current = try database.pool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'vectors.generation'")
        } ?? "0"
        guard current != generation else { return }
        var newIDs: [Int64] = []
        var newMatrix: [Float] = []
        var dim = 0
        try database.pool.read { db in
            let cursor = try Row.fetchCursor(db, sql: "SELECT chunk, vector FROM chunk_vectors ORDER BY chunk")
            while let row = try cursor.next() {
                let blob: Data = row["vector"]
                let floats = blob.count / MemoryLayout<Float>.size
                if dim == 0 {
                    dim = floats
                    newMatrix.reserveCapacity(dim * 1024)
                }
                guard floats == dim else { continue }
                newIDs.append(row["chunk"])
                blob.withUnsafeBytes { newMatrix.append(contentsOf: $0.bindMemory(to: Float.self)) }
            }
        }
        ids = newIDs
        matrix = newMatrix
        dimension = dim
        generation = current
    }
}
