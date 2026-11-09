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
