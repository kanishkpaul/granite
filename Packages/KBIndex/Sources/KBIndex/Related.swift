import Foundation
import GRDB
import KBCore

/// A note related to the one you are in, not yet linked from it.
public struct RelatedCandidate: Sendable, Hashable {
    public enum Reason: String, Sendable {
        /// The text names the note's title or alias without linking it.
        case mention
        /// A passage means something close (embedding similarity).
        case similar
    }

    public let path: String
    public let title: String
    public let reason: Reason
    /// 1 for a mention; cosine similarity of the best passage for `similar`.
    public let score: Double
    public let headingPath: String
    /// The mentioned words, or the start of the similar passage.
    public let snippet: String
    public let aiLabel: String

    public init(path: String, title: String, reason: Reason, score: Double, headingPath: String, snippet: String, aiLabel: String) {
        self.path = path
        self.title = title
        self.reason = reason
        self.score = score
        self.headingPath = headingPath
        self.snippet = snippet
        self.aiLabel = aiLabel
    }

    /// The wikilink to insert: the title when it names exactly one note, else the path.
    public var wikilink: String { "[[\(title)]]" }
}

/// Finds notes related to a note or a paragraph (master plan §7, idea 2): unlinked title and alias
/// mentions first, then passages close in meaning. Excludes the note itself, notes it already links,
/// and `AI/` (evidence scope). Works with keywords only when there are no vectors.
public struct RelatedFinder: Sendable {
    public let database: IndexDatabase
    public let vectors: VectorIndex?
    public let embedder: (any Embedder)?
    /// Cosine similarity below which a passage is not shown. Tune with acceptance data.
    public var minSimilarity: Float

    public init(database: IndexDatabase, vectors: VectorIndex?, embedder: (any Embedder)?, minSimilarity: Float = 0.6) {
        self.database = database
        self.vectors = vectors
        self.embedder = embedder
        self.minSimilarity = minSimilarity
    }

    /// Related to a whole note, from its stored chunk vectors and its text. No model call.
    public func forNote(_ path: String, limit: Int = 3) async throws -> [RelatedCandidate] {
        let (body, stored) = try await database.pool.read { db -> (String, [[Float]]) in
            let text = try String.fetchAll(db, sql: """
                SELECT b.text FROM blocks b JOIN objects o ON o.rowid = b.obj WHERE o.path = ? AND b.kind != 'code'
                ORDER BY b.start_line
                """, arguments: [path]).joined(separator: "\n")
            let vectors = try Data.fetchAll(db, sql: """
                SELECT v.vector FROM chunk_vectors v JOIN chunks c ON c.id = v.chunk JOIN objects o ON o.rowid = c.obj
                WHERE o.path = ?
                """, arguments: [path]).map(VectorMath.vector)
            return (text, vectors)
        }
        var query: [Float]?
        if let first = stored.first, stored.allSatisfy({ $0.count == first.count }) {
            var sum = [Float](repeating: 0, count: first.count)
            for vector in stored { for index in sum.indices { sum[index] += vector[index] } }
            query = sum
        }
        return try await find(text: body, vector: query, in: path, limit: limit)
    }

    /// Related to a paragraph you are writing: embeds it (one document embedding) when a model is loaded.
    public func forText(_ text: String, in path: String, limit: Int = 3) async throws -> [RelatedCandidate] {
        var vector: [Float]?
        if let embedder, text.split(separator: " ").count >= 4 {
            vector = try await embedder.embed(documents: [text]).first
        }
        return try await find(text: text, vector: vector, in: path, limit: limit)
    }

    func find(text: String, vector: [Float]?, in path: String, limit: Int) async throws -> [RelatedCandidate] {
        let excluded = try await excludedPaths(for: path)
        var results = try await mentions(in: text, excluding: excluded)
        var seen = Set(results.map(\.path)).union(excluded)
        // A paper's note and its full text share a title; the link resolves to the note either way.
        var titles = Set(results.map { $0.title.lowercased() })
        if let vector, let vectors, results.count < limit {
            let nearest = try await vectors.nearest(vector, k: 40).filter { $0.score >= minSimilarity }
            let rows = try await chunkRows(nearest.map(\.chunk))
            for (chunk, score) in nearest {
                guard let row = rows[chunk], !seen.contains(row.path), !Self.outOfScope(row.path, type: row.type),
                      titles.insert(row.title.lowercased()).inserted else { continue }
                seen.insert(row.path)
                results.append(RelatedCandidate(path: row.path, title: row.title, reason: .similar, score: Double(score),
                                                headingPath: row.headingPath, snippet: String(row.text.prefix(200)),
                                                aiLabel: row.aiLabel))
            }
        }
        return Array(results.prefix(limit))
    }

    static func outOfScope(_ path: String, type: String) -> Bool {
        path.hasPrefix("AI/") || ["proposal", "digest", "synthesis"].contains(type)
    }

    /// The note itself and every note it already links to.
    func excludedPaths(for path: String) async throws -> Set<String> {
        let linked = try await database.pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT d.path FROM links l JOIN objects s ON s.rowid = l.src JOIN objects d ON d.rowid = l.dst
                WHERE s.path = ?
                """, arguments: [path])
        }
        return Set(linked + [path])
    }

    struct ChunkRow {
        let path, title, type, headingPath, text, aiLabel: String
    }

    func chunkRows(_ chunks: [Int64]) async throws -> [Int64: ChunkRow] {
        guard !chunks.isEmpty else { return [:] }
        let json = "[" + chunks.map(String.init).joined(separator: ",") + "]"
        return try await database.pool.read { db in
            var rows: [Int64: ChunkRow] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT c.id, o.path, o.title, o.type, c.heading_path, c.text, o.ai_label FROM chunks c
                JOIN objects o ON o.rowid = c.obj WHERE c.id IN (SELECT value FROM json_each(?))
                """, arguments: [json]) {
                rows[row["id"]] = ChunkRow(path: row["path"], title: row["title"], type: row["type"],
                                           headingPath: row["heading_path"], text: row["text"], aiLabel: row["ai_label"])
            }
            return rows
        }
    }

    // MARK: Unlinked mentions

    /// Titles and aliases named in `text` outside links and code. Multi-word names match anywhere;
    /// one-word names only when written capitalized mid-sentence (to skip ordinary words).
    func mentions(in text: String, excluding excluded: Set<String>) async throws -> [RelatedCandidate] {
        let words = Self.words(in: Self.stripLinksAndCode(text))
        guard !words.isEmpty else { return [] }
        var phrases: [String: String] = [:]  // key → words as written
        for start in words.indices {
            for length in 1...5 where start + length <= words.count {
                let slice = words[start..<(start + length)]
                if length == 1 {
                    let word = slice[start]
                    guard word.text.count >= 4, word.capitalized, !word.sentenceStart else { continue }
                }
                let written = slice.map(\.text).joined(separator: " ")
                phrases[written.lowercased()] = phrases[written.lowercased()] ?? written
            }
        }
        let json = String(decoding: try JSONEncoder().encode(Array(phrases.keys)), as: UTF8.self)
        let rows = try await database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT o.path, o.title, o.type, o.ai_label, o.name_key AS key FROM objects o
                WHERE o.name_key IN (SELECT value FROM json_each(?1))
                UNION
                SELECT o.path, o.title, o.type, o.ai_label, a.alias_key AS key FROM aliases a JOIN objects o ON o.rowid = a.obj
                WHERE a.alias_key IN (SELECT value FROM json_each(?1))
                """, arguments: [json]).map { row -> (path: String, title: String, type: String, label: String, key: String) in
                    (row["path"], row["title"], row["type"], row["ai_label"], row["key"])
                }
        }
        var found: [String: RelatedCandidate] = [:]
        for (path, title, type, label, key) in rows {
            guard !excluded.contains(path), !Self.outOfScope(path, type: type) else { continue }
            let candidate = RelatedCandidate(path: path, title: title, reason: .mention, score: 1, headingPath: "",
                                             snippet: phrases[key] ?? key, aiLabel: label)
            // Longer mentions first: "Hybrid retrieval" beats a note called "Retrieval".
            if let existing = found[path], existing.snippet.count >= candidate.snippet.count { continue }
            found[path] = candidate
        }
        return found.values.sorted { ($0.snippet.count, $1.path) > ($1.snippet.count, $0.path) }
    }

    struct Word {
        let text: String
        let capitalized: Bool
        let sentenceStart: Bool
    }

    static func words(in text: String) -> [Word] {
        var words: [Word] = []
        var current = ""
        var sentenceStart = true
        func flush() {
            guard !current.isEmpty else { return }
            words.append(Word(text: current, capitalized: current.first?.isUppercase ?? false, sentenceStart: sentenceStart))
            sentenceStart = false
            current = ""
        }
        for character in text {
            if character.isLetter || character.isNumber || character == "-" || character == "'" {
                current.append(character)
            } else {
                flush()
                if ".!?:\n#>-*".contains(character) { sentenceStart = true }
            }
        }
        flush()
        return words
    }

    /// Removes `[[…]]`, `[…](…)`, inline code and fenced code so linked or quoted names aren't "mentions".
    static func stripLinksAndCode(_ text: String) -> String {
        var output = ""
        var inFence = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { inFence.toggle(); output += "\n"; continue }
            if inFence { output += "\n"; continue }
            output += line + "\n"
        }
        for pattern in ["!?\\[\\[[^\\]]*\\]\\]", "\\[[^\\]]*\\]\\([^)]*\\)", "`[^`]*`"] {
            output = output.replacingOccurrences(of: pattern, with: " . ", options: .regularExpression)
        }
        return output
    }
}

/// The see-also job (proposal queue v1): for each note, propose a link to its best unlinked
/// related note. Proposals only; nothing changes until you accept. Stops when the queue is full
/// or the feature is paused.
public struct SeeAlsoJob: Sendable {
    public static let feature = "see-also"
    /// Writes the one-line reason; nil keeps the plain one. Returns the reason and the model that wrote it.
    public typealias Justify = @Sendable (_ notePath: String, _ candidate: RelatedCandidate) async -> (reason: String, model: String)?

    let finder: RelatedFinder
    let store: ProposalStore
    let justify: Justify?

    public init(finder: RelatedFinder, store: ProposalStore, justify: Justify? = nil) {
        self.finder = finder
        self.store = store
        self.justify = justify
    }

    /// Notes worth proposing for: not AI output, not captures waiting in Inbox/, not private.
    public static func eligible(path: String, type: String, aiLabel: String) -> Bool {
        !path.hasPrefix("AI/") && !path.hasPrefix("Inbox/") && !path.hasPrefix("Papers/text/") && aiLabel != AILabel.none.rawValue
            && !["proposal", "digest", "synthesis"].contains(type)
    }

    /// Returns the paths of the proposals it wrote.
    public func run(paths: [String], now: Date = Date()) async throws -> [String] {
        var created: [String] = []
        for path in paths {
            guard let note = try finder.database.note(path: path),
                  Self.eligible(path: path, type: note.type, aiLabel: note.aiLabel) else { continue }
            let candidates = try await finder.forNote(path, limit: 3).filter { $0.aiLabel != AILabel.none.rawValue }
            for candidate in candidates {
                let line = "- \(candidate.wikilink) — " + (candidate.reason == .mention ? "mentioned here" : "related")
                let plain = candidate.reason == .mention
                    ? "This note mentions “\(candidate.snippet)” without linking it."
                    : "A passage in \(candidate.wikilink)\(candidate.headingPath.isEmpty ? "" : " (\(candidate.headingPath))") "
                        + "reads close to this note: “\(candidate.snippet.prefix(140))…”"
                let written = await justify?(path, candidate)
                let labels = [note.aiLabel, candidate.aiLabel].compactMap(AILabel.init(rawValue:))
                let proposal = Proposal(kind: .link, target: "[[\(String(path.dropLast(3)))]]", feature: Self.feature,
                                        model: written?.model ?? "none", rationale: written?.reason ?? plain,
                                        change: ProposalChange(added: [line]), citations: [candidate.wikilink],
                                        created: "", label: AILabel.strictest(labels))
                do {
                    created.append(try await store.create(proposal, now: now))
                    break  // one per note per run
                } catch ProposalStoreError.duplicate {
                    continue  // already proposed or rejected: try the next candidate
                } catch let error as ProposalStoreError {
                    if case .queueFull = error { return created }
                    if case .paused = error { return created }
                    throw error
                }
            }
        }
        return created
    }
}
