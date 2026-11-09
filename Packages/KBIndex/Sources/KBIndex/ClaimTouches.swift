import Foundation
import GRDB
import KBCore

/// "A new source touches a held claim" (master plan §5 step 6, §7 idea 7): passages of recent
/// sources whose vectors are close to a held claim's. A cue to reread, not a verdict.
public struct ClaimTouch: Sendable, Hashable {
    public let source: String
    public let sourceTitle: String
    public let headingPath: String
    public let claim: String
    public let claimTitle: String
    public let similarity: Double
    public let passage: String
}

public enum ClaimTouches {
    /// Pairs above `threshold`, best first, one per source and claim.
    public static func find(in database: IndexDatabase, sourcesSince since: Date, threshold: Double = 0.75,
                            limit: Int = 20) throws -> [ClaimTouch] {
        try database.pool.read { db in
            struct Vec { let path, title, heading, text: String; let vector: [Float] }
            func vectors(_ sql: String, _ arguments: StatementArguments = []) throws -> [Vec] {
                try Row.fetchAll(db, sql: sql, arguments: arguments).map {
                    Vec(path: $0["path"], title: $0["title"], heading: $0["heading_path"], text: $0["text"],
                        vector: VectorMath.normalized(VectorMath.vector($0["vector"])))
                }
            }
            let sources = try vectors("""
                SELECT o.path, o.title, c.heading_path, c.text, v.vector FROM chunk_vectors v
                JOIN chunks c ON c.id = v.chunk JOIN objects o ON o.rowid = c.obj
                WHERE o.type = 'source' AND o.mtime >= ? AND o.ai_label != 'none'
                """, [since.timeIntervalSinceReferenceDate])
            guard !sources.isEmpty else { return [] }
            let claims = try vectors("""
                SELECT o.path, o.title, c.heading_path, c.text, v.vector FROM chunk_vectors v
                JOIN chunks c ON c.id = v.chunk JOIN objects o ON o.rowid = c.obj
                WHERE o.type = 'claim' AND o.status = 'held'
                """)
            var best: [String: ClaimTouch] = [:]
            for claim in claims {
                for source in sources where source.vector.count == claim.vector.count {
                    let similarity = Double(zip(claim.vector, source.vector).reduce(Float(0)) { $0 + $1.0 * $1.1 })
                    guard similarity >= threshold else { continue }
                    let key = "\(source.path)|\(claim.path)"
                    if (best[key]?.similarity ?? -1) < similarity {
                        best[key] = ClaimTouch(source: source.path, sourceTitle: source.title, headingPath: source.heading,
                                               claim: claim.path, claimTitle: claim.title, similarity: similarity,
                                               passage: String(source.text.prefix(200)))
                    }
                }
            }
            return Array(best.values.sorted { $0.similarity > $1.similarity }.prefix(limit))
        }
    }
}

/// Two held claims about the same thing (master plan §7, contradiction detection): candidates
/// for a contradiction check, by vector similarity.
public struct ClaimPair: Sendable, Hashable {
    public let first: String
    public let firstTitle: String
    public let firstText: String
    public let second: String
    public let secondTitle: String
    public let secondText: String
    public let similarity: Double
}

public enum ClaimPairs {
    /// Held-claim pairs above `threshold`, most similar first. Pairs already linked with
    /// `contradicts` or `supersedes` are skipped (you've recorded the relation).
    public static func similar(in database: IndexDatabase, threshold: Double = 0.7, limit: Int = 10) throws -> [ClaimPair] {
        try database.pool.read { db in
            struct Claim { let rowid: Int64; let path, title, text: String; let vector: [Float] }
            var claims: [Int64: Claim] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT o.rowid, o.path, o.title, c.text, v.vector FROM chunk_vectors v JOIN chunks c ON c.id = v.chunk
                JOIN objects o ON o.rowid = c.obj WHERE o.type = 'claim' AND o.status = 'held' ORDER BY c.id
                """) {
                let rowid: Int64 = row["rowid"]
                guard claims[rowid] == nil else { continue }  // first chunk: claims are short
                claims[rowid] = Claim(rowid: rowid, path: row["path"], title: row["title"], text: row["text"],
                                      vector: VectorMath.normalized(VectorMath.vector(row["vector"])))
            }
            var related = Set<String>()
            for row in try Row.fetchAll(db, sql: "SELECT src, dst FROM links WHERE rel IN ('contradicts', 'supersedes', 'supports') AND dst IS NOT NULL") {
                let a: Int64 = row["src"], b: Int64 = row["dst"]
                related.insert("\(min(a, b))-\(max(a, b))")
            }
            let list = claims.values.sorted { $0.path < $1.path }
            var pairs: [ClaimPair] = []
            for i in list.indices {
                for j in list.indices where j > i && list[i].vector.count == list[j].vector.count {
                    let a = list[i], b = list[j]
                    guard !related.contains("\(min(a.rowid, b.rowid))-\(max(a.rowid, b.rowid))") else { continue }
                    let similarity = Double(zip(a.vector, b.vector).reduce(Float(0)) { $0 + $1.0 * $1.1 })
                    guard similarity >= threshold else { continue }
                    pairs.append(ClaimPair(first: a.path, firstTitle: a.title, firstText: a.text, second: b.path, secondTitle: b.title,
                                           secondText: b.text, similarity: similarity))
                }
            }
            return Array(pairs.sorted { $0.similarity > $1.similarity }.prefix(limit))
        }
    }
}
