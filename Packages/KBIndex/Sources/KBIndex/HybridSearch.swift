import Foundation
import GRDB
import KBCore

public struct HybridOptions: Sendable {
    public enum Mode: String, Sendable, CaseIterable {
        case bm25, vector, hybrid
    }

    public var mode: Mode = .hybrid
    public var limit = 10
    /// Candidates taken from each retriever before fusion.
    public var candidates = 50
    /// How many fused chunks the reranker scores.
    public var rerankTop = 30
    public var useReranker = true
    /// Reciprocal-rank-fusion constant (master plan §6.2).
    public var rrfK = 60.0
    /// With a reranker: answer "no note on that" when the best score is below this.
    public var abstainBelow: Double?
    public var includeAI = false
    public var maxLabel: AILabel?
    public var folders: [String] = []

    public init() {}
}

public struct HybridHit: Sendable {
    public let chunk: Int64
    public let path: String
    public let title: String
    public let type: String
    public let origin: String
    public let headingPath: String
    public let text: String
    /// One-based line where the chunk starts, and the first block's `^id`, for citations.
    public let startLine: Int
    public let endLine: Int
    public let blockID: String?
    /// The note's AI label, so callers can apply taint.
    public let aiLabel: String
    public let bm25Rank: Int?
    public let vectorRank: Int?
    public let fused: Double
    public let rerankScore: Double?

    public init(chunk: Int64, path: String, title: String, type: String, origin: String, headingPath: String, text: String,
                startLine: Int, endLine: Int, blockID: String?, aiLabel: String, bm25Rank: Int?, vectorRank: Int?,
                fused: Double, rerankScore: Double?) {
        self.chunk = chunk
        self.path = path
        self.title = title
        self.type = type
        self.origin = origin
        self.headingPath = headingPath
        self.text = text
        self.startLine = startLine
        self.endLine = endLine
        self.blockID = blockID
        self.aiLabel = aiLabel
        self.bm25Rank = bm25Rank
        self.vectorRank = vectorRank
        self.fused = fused
        self.rerankScore = rerankScore
    }
}

public struct HybridResult: Sendable {
    public let hits: [HybridHit]
    /// The reranker's best score fell below `abstainBelow`: no note answers this.
    public let abstained: Bool
    /// Milliseconds per stage: bm25, embed, vector, fuse, rerank, total.
    public let timings: [String: Double]

    public init(hits: [HybridHit], abstained: Bool, timings: [String: Double]) {
        self.hits = hits
        self.abstained = abstained
        self.timings = timings
    }
}

/// BM25 ∥ vectors → RRF → optional rerank → best chunk per note (master plan §6.2).
/// Works without an embedder (BM25 only) and without a reranker (fusion order).
public struct HybridSearcher: Sendable {
    public let database: IndexDatabase
    public let vectors: VectorIndex?
    public let embedder: (any Embedder)?
    public let reranker: (any Reranker)?

    public init(database: IndexDatabase, vectors: VectorIndex?, embedder: (any Embedder)?, reranker: (any Reranker)?) {
        self.database = database
        self.vectors = vectors
        self.embedder = embedder
        self.reranker = reranker
    }

    public func search(_ query: String, options: HybridOptions = HybridOptions()) async throws -> HybridResult {
        let clock = ContinuousClock()
        let start = clock.now
        var timings: [String: Double] = [:]
        func lap(_ name: String, since: ContinuousClock.Instant) {
            let elapsed = clock.now - since
            timings[name] = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        }

        // 1. Keyword candidates (chunk level: a chunk's rank is its best block's rank).
        var bm25: [Int64] = []
        if options.mode != .vector, let match = try? IndexDatabase.ftsQuery(query) {
            let t = clock.now
            bm25 = try keywordChunks(match: match, options: options)
            lap("bm25", since: t)
        }

        // 2. Vector candidates.
        var nearest: [Int64] = []
        if options.mode != .bm25, let embedder, let vectors {
            var t = clock.now
            let vector = try await embedder.embed(query: query)
            lap("embed", since: t)
            t = clock.now
            let raw = try await vectors.nearest(vector, k: options.candidates * 4)
            nearest = try allowed(raw.map(\.chunk), options: options).prefix(options.candidates).map { $0 }
            lap("vector", since: t)
        }

        // 3. Reciprocal rank fusion.
        let t = clock.now
        var fused: [Int64: Double] = [:]
        var bm25Rank: [Int64: Int] = [:]
        var vectorRank: [Int64: Int] = [:]
        for (rank, chunk) in bm25.enumerated() {
            fused[chunk, default: 0] += 1 / (options.rrfK + Double(rank + 1))
            bm25Rank[chunk] = rank + 1
        }
        for (rank, chunk) in nearest.enumerated() {
            fused[chunk, default: 0] += 1 / (options.rrfK + Double(rank + 1))
            vectorRank[chunk] = rank + 1
        }
        let ordered = fused.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        let keep = options.useReranker && reranker != nil ? options.rerankTop : options.limit * 4
        let top = Array(ordered.prefix(keep))
        var rows = try details(Array(top.map(\.key)))
        lap("fuse", since: t)

        // 4. Rerank.
        var rerank: [Int64: Double] = [:]
        var abstained = false
        if options.useReranker, let reranker, !rows.isEmpty {
            let t = clock.now
            let scores = try await reranker.scores(query: query, documents: rows.map { $0.prefix + "\n" + $0.text })
            for (row, score) in zip(rows, scores) { rerank[row.chunk] = score }
            rows.sort { (rerank[$0.chunk] ?? 0) > (rerank[$1.chunk] ?? 0) }
            if let threshold = options.abstainBelow, (scores.max() ?? 0) < threshold { abstained = true }
            lap("rerank", since: t)
        } else {
            let order = Dictionary(uniqueKeysWithValues: top.enumerated().map { ($1.key, $0) })
            rows.sort { (order[$0.chunk] ?? .max) < (order[$1.chunk] ?? .max) }
        }

        // 5. Best chunk per note.
        var seen = Set<String>()
        var hits: [HybridHit] = []
        for row in rows where seen.insert(row.path).inserted {
            hits.append(HybridHit(chunk: row.chunk, path: row.path, title: row.title, type: row.type, origin: row.origin,
                                  headingPath: row.headingPath, text: row.text, startLine: row.startLine,
                                  endLine: row.endLine, blockID: row.blockID, aiLabel: row.aiLabel, bm25Rank: bm25Rank[row.chunk],
                                  vectorRank: vectorRank[row.chunk], fused: fused[row.chunk] ?? 0,
                                  rerankScore: rerank[row.chunk]))
            if hits.count == options.limit { break }
        }
        lap("total", since: start)
        return HybridResult(hits: abstained ? [] : hits, abstained: abstained, timings: timings)
    }

    // MARK: SQL

    struct ChunkRow: Sendable {
        let chunk: Int64
        let path: String
        let title: String
        let type: String
        let origin: String
        let headingPath: String
        let prefix: String
        let text: String
        let startLine: Int
        let endLine: Int
        let blockID: String?
        let aiLabel: String
    }

    func filterSQL(_ options: HybridOptions) -> (String, StatementArguments) {
        var clauses: [String] = []
        var arguments: StatementArguments = []
        if !options.includeAI { clauses.append("o.origin != 'ai'") }
        if let maxLabel = options.maxLabel {
            let allowed = AILabel.allCases.filter { $0 <= maxLabel }.map { "'\($0.rawValue)'" }.joined(separator: ",")
            clauses.append("o.ai_label IN (\(allowed))")
        }
        if !options.folders.isEmpty {
            clauses.append("(" + options.folders.map { _ in "substr(o.path_key, 1, ?) = ?" }.joined(separator: " OR ") + ")")
            for folder in options.folders {
                var prefix = folder.lowercased()
                if !prefix.hasSuffix("/") { prefix += "/" }
                _ = arguments.append(contentsOf: [prefix.count, prefix])
            }
        }
        return (clauses.isEmpty ? "" : " AND " + clauses.joined(separator: " AND "), arguments)
    }

    func keywordChunks(match: String, options: HybridOptions) throws -> [Int64] {
        let (filter, filterArguments) = filterSQL(options)
        var arguments: StatementArguments = [match]
        _ = arguments.append(contentsOf: filterArguments)
        _ = arguments.append(contentsOf: [options.candidates])
        return try database.pool.read { db in
            try Int64.fetchAll(db, sql: """
                WITH ranked AS (
                  SELECT rowid AS id, bm25(blocks_fts, 1.0, 0.4) AS score FROM blocks_fts
                  WHERE blocks_fts MATCH ? ORDER BY score LIMIT 400
                )
                SELECT c.id FROM ranked
                JOIN blocks b ON b.id = ranked.id
                JOIN chunks c ON c.obj = b.obj AND b.id BETWEEN c.first_block AND c.last_block
                JOIN objects o ON o.rowid = c.obj
                WHERE 1 = 1\(filter)
                GROUP BY c.id ORDER BY min(ranked.score) LIMIT ?
                """, arguments: arguments)
        }
    }

    /// Keeps chunk ids that still exist and pass the filters, in the given order.
    func allowed(_ chunks: [Int64], options: HybridOptions) throws -> [Int64] {
        guard !chunks.isEmpty else { return [] }
        let (filter, filterArguments) = filterSQL(options)
        var arguments: StatementArguments = [String(decoding: try JSONEncoder().encode(chunks), as: UTF8.self)]
        _ = arguments.append(contentsOf: filterArguments)
        let kept = try database.pool.read { db in
            Set(try Int64.fetchAll(db, sql: """
                SELECT c.id FROM chunks c JOIN objects o ON o.rowid = c.obj
                WHERE c.id IN (SELECT value FROM json_each(?))\(filter)
                """, arguments: arguments))
        }
        return chunks.filter { kept.contains($0) }
    }

    func details(_ chunks: [Int64]) throws -> [ChunkRow] {
        guard !chunks.isEmpty else { return [] }
        let json = String(decoding: try JSONEncoder().encode(chunks), as: UTF8.self)
        return try database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT c.id, o.path, o.title, o.type, o.origin, o.ai_label, c.heading_path, c.prefix, c.text,
                       fb.start_line, lb.end_line, fb.block_id
                FROM chunks c JOIN objects o ON o.rowid = c.obj
                JOIN blocks fb ON fb.id = c.first_block JOIN blocks lb ON lb.id = c.last_block
                WHERE c.id IN (SELECT value FROM json_each(?))
                """, arguments: [json])
            .map { ChunkRow(chunk: $0["id"], path: $0["path"], title: $0["title"], type: $0["type"], origin: $0["origin"],
                            headingPath: $0["heading_path"], prefix: $0["prefix"], text: $0["text"],
                            startLine: $0["start_line"], endLine: $0["end_line"], blockID: $0["block_id"],
                            aiLabel: $0["ai_label"]) }
        }
    }
}
