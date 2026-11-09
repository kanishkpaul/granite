import Foundation
import GRDB
import KBCore

public struct SearchHit: Sendable, Hashable {
    public let path: String
    public let title: String
    public let type: String
    public let origin: String
    public let headingPath: String
    public let snippet: String
    public let startLine: Int
    public let blockID: String?
    /// FTS5 bm25: lower is better.
    public let score: Double
}

public struct SearchOptions: Sendable {
    public var limit: Int
    /// Evidence scope (principle 4): `AI/` is excluded unless asked for.
    public var includeAI: Bool
    /// Only notes whose label is at most this strict pass, e.g. `.cloud` for MCP.
    public var maxLabel: AILabel?
    /// Vault-relative folder prefixes to search within.
    public var folders: [String]
    /// Treat the query as raw FTS5 syntax instead of plain words.
    public var raw: Bool

    public init(limit: Int = 20, includeAI: Bool = false, maxLabel: AILabel? = nil, folders: [String] = [],
                raw: Bool = false) {
        self.limit = limit
        self.includeAI = includeAI
        self.maxLabel = maxLabel
        self.folders = folders
        self.raw = raw
    }
}

public struct NoteSummary: Sendable, Hashable {
    public let path: String
    public let title: String
    public let type: String
}

public struct Backlink: Sendable, Hashable {
    public let path: String
    public let title: String
    public let relation: String
    public let line: Int
}

public struct IndexStats: Sendable, Hashable {
    public let objects: Int
    public let blocks: Int
    public let links: Int
    public let unresolvedLinks: Int
    public let tags: Int
    public let yamlErrors: Int
}

public enum QueryError: Error, CustomStringConvertible {
    case emptyQuery
    case notFound(String)

    public var description: String {
        switch self {
        case .emptyQuery: "the query has no searchable words"
        case .notFound(let path): "no indexed note at \(path)"
        }
    }
}

extension IndexDatabase {
    /// Full-text search over blocks, best block per note, bm25-ranked.
    public func search(_ query: String, options: SearchOptions = SearchOptions()) throws -> [SearchHit] {
        let match = options.raw ? query : try Self.ftsQuery(query)
        var filters: [String] = []
        var arguments: StatementArguments = [match]
        if !options.includeAI { filters.append("o.origin != 'ai'") }
        if let maxLabel = options.maxLabel {
            let allowed = AILabel.allCases.filter { $0 <= maxLabel }.map { "'\($0.rawValue)'" }.joined(separator: ",")
            filters.append("o.ai_label IN (\(allowed))")
        }
        if !options.folders.isEmpty {
            filters.append("(" + options.folders.map { _ in "o.path_key LIKE ? ESCAPE '\\'" }.joined(separator: " OR ") + ")")
            for folder in options.folders {
                var prefix = folder.lowercased()
                if !prefix.hasSuffix("/") { prefix += "/" }
                let escaped = prefix.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
                _ = arguments.append(contentsOf: [escaped + "%"])
            }
        }
        // Fast path: FTS5 ranks inside the virtual table and hands back only the top rowids,
        // so the joins and filters touch a few hundred rows instead of every matching block.
        let candidates = max(200, options.limit * 20)
        let filter = filters.isEmpty ? "" : "WHERE " + filters.joined(separator: " AND ")
        let fast = """
        WITH ranked AS (
          SELECT rowid AS id, bm25(blocks_fts, 1.0, 0.4) AS score FROM blocks_fts
          WHERE blocks_fts MATCH ? ORDER BY score LIMIT \(candidates)
        )
        SELECT b.id, o.path, o.title, o.type, o.origin, b.heading_path, b.start_line, b.block_id, ranked.score
        FROM ranked JOIN blocks b ON b.id = ranked.id JOIN objects o ON o.rowid = b.obj
        \(filter)
        ORDER BY ranked.score
        """
        // Exhaustive path, used only when filters drop too many fast-path candidates.
        let exhaustive = """
        SELECT b.id, o.path, o.title, o.type, o.origin, b.heading_path, b.start_line, b.block_id,
               bm25(blocks_fts, 1.0, 0.4) AS score
        FROM blocks_fts JOIN blocks b ON b.id = blocks_fts.rowid JOIN objects o ON o.rowid = b.obj
        WHERE blocks_fts MATCH ? \(filters.isEmpty ? "" : "AND " + filters.joined(separator: " AND "))
        ORDER BY score LIMIT \(options.limit * 8)
        """
        let limit = options.limit
        return try pool.read { db in
            func best(_ rows: [Row]) -> [Row] {
                var seen = Set<String>()
                var kept: [Row] = []
                for row in rows where seen.insert(row["path"]).inserted {
                    kept.append(row)
                    if kept.count == limit { break }
                }
                return kept
            }
            let fastRows = try Row.fetchAll(db, sql: fast, arguments: arguments)
            var rows = best(fastRows)
            // Too few survivors and the candidate list was full: filtered-out notes may hide better ones.
            if rows.count < limit, fastRows.count < candidates || !filters.isEmpty,
               try Int.fetchOne(db, sql: "SELECT count(*) FROM (SELECT 1 FROM blocks_fts WHERE blocks_fts MATCH ? LIMIT \(candidates))",
                                arguments: [match]) == candidates {
                rows = best(try Row.fetchAll(db, sql: exhaustive, arguments: arguments))
            }
            let snippet = try db.cachedStatement(sql: """
                SELECT snippet(blocks_fts, 0, '[', ']', '…', 16) FROM blocks_fts WHERE blocks_fts MATCH ? AND rowid = ?
                """)
            return try rows.map { row in
                let id: Int64 = row["id"]
                let text = try String.fetchOne(snippet, arguments: [match, id]) ?? ""
                return SearchHit(path: row["path"], title: row["title"], type: row["type"], origin: row["origin"],
                                 headingPath: row["heading_path"], snippet: text, startLine: row["start_line"],
                                 blockID: row["block_id"], score: row["score"])
            }
        }
    }

    /// Plain words → an FTS5 query: every word must match; the last one also matches as a prefix
    /// (once it has 3+ characters) so search-as-you-type works. Quotes neutralize FTS5 operators.
    public static func ftsQuery(_ text: String) throws -> String {
        var words: [String] = []
        var current = ""
        for scalar in text.unicodeScalars {
            if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        guard !words.isEmpty else { throw QueryError.emptyQuery }
        let endsMidWord = text.unicodeScalars.last.map { $0.properties.isAlphabetic || $0.properties.numericType != nil } ?? false
        return words.enumerated().map { index, word in
            let quoted = "\"\(word)\""
            let isPrefix = index == words.count - 1 && endsMidWord && word.count >= 3
            return isPrefix ? quoted + "*" : quoted
        }.joined(separator: " ")
    }

    /// Quick-switcher title match: prefix matches first, then substring, shortest titles first.
    public func titles(matching text: String, limit: Int = 20) throws -> [NoteSummary] {
        let key = text.lowercased().trimmingCharacters(in: .whitespaces)
        let escaped = key.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
        return try pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT path, title, type FROM objects
                WHERE name_key LIKE ? ESCAPE '\\' OR rowid IN (SELECT obj FROM aliases WHERE alias_key LIKE ? ESCAPE '\\')
                ORDER BY (name_key LIKE ? ESCAPE '\\') DESC, length(title), title
                LIMIT ?
                """, arguments: ["%" + escaped + "%", "%" + escaped + "%", escaped + "%", limit])
            .map { NoteSummary(path: $0["path"], title: $0["title"], type: $0["type"]) }
        }
    }

    public func backlinks(to path: String) throws -> [Backlink] {
        try pool.read { db in
            guard let rowid = try Int64.fetchOne(db, sql: "SELECT rowid FROM objects WHERE path = ?", arguments: [path]) else {
                throw QueryError.notFound(path)
            }
            return try Row.fetchAll(db, sql: """
                SELECT o.path, o.title, l.rel, l.line FROM links l JOIN objects o ON o.rowid = l.src
                WHERE l.dst = ? AND l.src != l.dst
                ORDER BY o.path, l.line
                """, arguments: [rowid])
            .map { Backlink(path: $0["path"], title: $0["title"], relation: $0["rel"], line: $0["line"]) }
        }
    }

    /// Link targets that match no note, with how often each is used.
    public func unresolvedLinks(limit: Int = 50) throws -> [(target: String, count: Int)] {
        try pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT min(target_text) AS target, count(*) AS n FROM links
                WHERE dst IS NULL GROUP BY target_key ORDER BY n DESC, target LIMIT ?
                """, arguments: [limit])
            .map { (target: $0["target"], count: $0["n"]) }
        }
    }

    public func stats() throws -> IndexStats {
        try pool.read { db in
            func count(_ sql: String) throws -> Int { try Int.fetchOne(db, sql: sql) ?? 0 }
            return IndexStats(
                objects: try count("SELECT count(*) FROM objects"),
                blocks: try count("SELECT count(*) FROM blocks"),
                links: try count("SELECT count(*) FROM links"),
                unresolvedLinks: try count("SELECT count(*) FROM links WHERE dst IS NULL"),
                tags: try count("SELECT count(DISTINCT tag_key) FROM tags"),
                yamlErrors: try count("SELECT count(*) FROM objects WHERE yaml_error IS NOT NULL")
            )
        }
    }
}

extension IndexDatabase {
    /// Lowercased link keys in a note that resolve to an indexed note, for editor styling.
    public func resolvedTargets(from path: String) throws -> [String] {
        try pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT l.target_key FROM links l JOIN objects o ON o.rowid = l.src
                WHERE o.path = ? AND l.dst IS NOT NULL AND l.target_key != ''
                ORDER BY l.target_key
                """, arguments: [path])
        }
    }
}

extension IndexDatabase {
    /// Resolves a link target to a vault path, in the same order the indexer uses:
    /// exact path, file name (shortest path wins), path suffix, alias. Empty target = `from`.
    public func resolve(linkTarget target: String, from path: String) throws -> String? {
        let key = LinkRef.key(for: target)
        if key.isEmpty { return path }
        return try pool.read { db in
            if let exact = try String.fetchOne(db, sql: "SELECT path FROM objects WHERE path_key = ?", arguments: [key]) {
                return exact
            }
            if !key.contains("/"),
               let byName = try String.fetchOne(db, sql: "SELECT path FROM objects WHERE name_key = ? ORDER BY length(path), path LIMIT 1",
                                               arguments: [key]) {
                return byName
            }
            if key.contains("/"),
               let bySuffix = try String.fetchOne(db, sql: "SELECT path FROM objects WHERE path_key LIKE '%/' || ? ORDER BY length(path) LIMIT 1",
                                                 arguments: [key]) {
                return bySuffix
            }
            return try String.fetchOne(db, sql: """
                SELECT o.path FROM aliases a JOIN objects o ON o.rowid = a.obj WHERE a.alias_key = ? LIMIT 1
                """, arguments: [key])
        }
    }
}

/// One indexed note's metadata.
public struct NoteRecord: Sendable, Hashable {
    public let path: String
    public let id: String?
    public let title: String
    public let type: String
    public let origin: String
    public let aiLabel: String
    /// Seconds since the reference date (2001-01-01), as stored by the indexer.
    public let mtime: Double

    public var modified: Date { Date(timeIntervalSinceReferenceDate: mtime) }
}

extension IndexDatabase {
    private static let noteColumns = "path, id, title, type, origin, ai_label, mtime"

    private static func record(_ row: Row) -> NoteRecord {
        NoteRecord(path: row["path"], id: row["id"], title: row["title"], type: row["type"], origin: row["origin"],
                   aiLabel: row["ai_label"], mtime: row["mtime"])
    }

    public func note(path: String) throws -> NoteRecord? {
        try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT \(Self.noteColumns) FROM objects WHERE path = ?", arguments: [path])
                .map(Self.record)
        }
    }

    /// Looks a note up by its frontmatter `id`. Duplicate ids (copied files) return the shortest path.
    public func note(id: String) throws -> NoteRecord? {
        try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT \(Self.noteColumns) FROM objects WHERE id = ? ORDER BY length(path), path LIMIT 1",
                             arguments: [id]).map(Self.record)
        }
    }

    /// Most recently modified notes first, optionally only those modified at or after `since`.
    public func recent(limit: Int, since: Date? = nil) throws -> [NoteRecord] {
        try pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT \(Self.noteColumns) FROM objects WHERE mtime >= ? ORDER BY mtime DESC, path LIMIT ?
                """, arguments: [since?.timeIntervalSinceReferenceDate ?? -Double.greatestFiniteMagnitude, limit])
            .map(Self.record)
        }
    }
}
