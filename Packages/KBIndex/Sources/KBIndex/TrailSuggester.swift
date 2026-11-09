import Foundation
import GRDB
import KBCore

/// Candidate trails from your own link graph: chains of at least three recently changed notes,
/// each linking to the next (master plan §7, idea 10). Proposals only; you name and endorse them.
public enum TrailSuggester {
    public static func chains(in database: IndexDatabase, since: Date, minimum: Int = 3, maximum: Int = 7, limit: Int = 3) throws -> [[String]] {
        let edges = try database.pool.read { db -> [(String, String)] in
            try Row.fetchAll(db, sql: """
                SELECT DISTINCT s.path AS src, d.path AS dst FROM links l
                JOIN objects s ON s.rowid = l.src JOIN objects d ON d.rowid = l.dst
                WHERE s.mtime >= ? AND s.type IN ('note', 'claim', 'decision', 'source') AND d.type IN ('note', 'claim', 'decision', 'source')
                  AND s.path NOT LIKE 'AI/%' AND d.path NOT LIKE 'AI/%' AND s.path NOT LIKE 'Daily/%' AND s.path NOT LIKE 'Inbox/%'
                  AND s.path != d.path AND coalesce(s.kind, '') != 'trail' AND s.ai_label != 'none' AND d.ai_label != 'none'
                """, arguments: [since.timeIntervalSinceReferenceDate]).map { ($0["src"], $0["dst"]) }
        }
        var outgoing: [String: [String]] = [:]
        var incoming: [String: Int] = [:]
        for (src, dst) in edges {
            outgoing[src, default: []].append(dst)
            incoming[dst, default: 0] += 1
        }
        // Longest chain first (ties: fewer links in to its start, then name); no note in two trails.
        var used = Set<String>()
        var chains: [[String]] = []
        func walk(from start: String) -> [String] {
            var chain = [start]
            var current = start
            while chain.count < maximum, let next = (outgoing[current] ?? []).sorted().first(where: { !chain.contains($0) && !used.contains($0) }) {
                chain.append(next)
                current = next
            }
            return chain
        }
        while chains.count < limit {
            let best = outgoing.keys.filter { !used.contains($0) }.map(walk)
                .filter { $0.count >= minimum }
                .min { ($1.count, incoming[$0[0]] ?? 0, $0[0]) < ($0.count, incoming[$1[0]] ?? 0, $1[0]) }
            guard let best else { break }
            chains.append(best)
            used.formUnion(best)
        }
        return chains
    }
}

extension IndexDatabase {
    /// The note a chunk belongs to.
    public func path(ofChunk id: Int64) throws -> String? {
        try pool.read { db in
            try String.fetchOne(db, sql: "SELECT o.path FROM chunks c JOIN objects o ON o.rowid = c.obj WHERE c.id = ?", arguments: [id])
        }
    }

    /// Every DOI written in a note's frontmatter (lowercased), to skip papers already in the vault.
    public func knownDOIs() throws -> Set<String> {
        try pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT lower(v_text) FROM props WHERE key = 'doi' AND v_text IS NOT NULL"))
        }
    }
}
