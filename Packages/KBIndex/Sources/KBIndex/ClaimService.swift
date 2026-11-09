import Foundation
import GRDB
import KBCore

/// A claim as the ledger shows it.
public struct ClaimRecord: Sendable, Hashable, Identifiable {
    public let path: String
    public let title: String
    public let status: ClaimStatus
    public let confidence: Double?
    public let asOf: String?
    public let tags: [String]
    public var id: String { path }
}

public enum ClaimError: Error, Equatable, CustomStringConvertible {
    case empty
    case notAClaim(String)
    case cannotCite(String)

    public var description: String {
        switch self {
        case .empty: "a claim needs some text"
        case .notAClaim(let path): "\(path) is not a claim"
        case .cannotCite(let path): "pick a paragraph or list item in \(path) to cite (not a heading or code)"
        }
    }
}

/// The claim and belief ledger (master plan §7, idea 5): promote a sentence to a claim that cites
/// it, supersede a claim with a new one (the old body stays as written), and read the history.
public actor ClaimService {
    public static let folder = "Notes"
    public let indexer: Indexer
    let writer: SafeWriter
    let calendar: Calendar

    public init(indexer: Indexer, writer: SafeWriter, calendar: Calendar = .current) {
        self.indexer = indexer
        self.writer = writer
        self.calendar = calendar
    }

    var database: IndexDatabase { indexer.database }
    var vault: Vault { indexer.vault }

    /// Promotes `text` (a sentence you wrote in `path`, around `line`) to a claim file citing that
    /// block. Adds a `^c-…` block id to the source paragraph if it has none. Returns the claim's path.
    public func promote(_ text: String, from path: String, line: Int, confidence: Double = 0.7, now: Date = Date()) async throws -> String {
        let claim = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !claim.isEmpty else { throw ClaimError.empty }
        let source = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        guard let (cited, blockID) = ClaimNote.ensureBlockID(in: source, line: line) else { throw ClaimError.cannotCite(path) }
        if cited != source { try await writer.write(cited, to: path, as: .user) }
        let link = "[[\(try await linkTarget(for: path))#^\(blockID)]]"
        let created = try await create(claim, sources: [link], supersedes: [], confidence: confidence, now: now)
        _ = try await indexer.update(paths: [path, created])
        return created
    }

    /// Writes a new claim that supersedes `path`, and marks the old one `superseded` (frontmatter
    /// only; its text is left as you wrote it). Returns the new claim's path.
    public func supersede(_ path: String, with text: String, confidence: Double = 0.7, now: Date = Date()) async throws -> String {
        let claim = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !claim.isEmpty else { throw ClaimError.empty }
        let old = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        guard MarkdownDocument(text: old).frontmatter?["type"]?.text == ObjectType.claim.rawValue else { throw ClaimError.notAClaim(path) }
        let created = try await create(claim, sources: [], supersedes: ["[[\(try await linkTarget(for: path))]]"],
                                       confidence: confidence, now: now)
        try await writer.write(try FrontmatterEditor.setScalar("status", to: ClaimStatus.superseded.rawValue, in: old), to: path, as: .user)
        _ = try await indexer.update(paths: [path, created])
        return created
    }

    /// Sets status (held, revised, retired…) and, for anything but retirement, a fresh `as_of`.
    public func setStatus(_ status: ClaimStatus, of path: String, now: Date = Date()) async throws {
        let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        guard MarkdownDocument(text: text).frontmatter?["type"]?.text == ObjectType.claim.rawValue else { throw ClaimError.notAClaim(path) }
        var updated = try FrontmatterEditor.setScalar("status", to: status.rawValue, in: text)
        if status != .retired { updated = try FrontmatterEditor.setScalar("as_of", to: Self.day(now, calendar), in: updated) }
        try await writer.write(updated, to: path, as: .user)
        _ = try await indexer.update(paths: [path])
    }

    // MARK: Reading

    /// Every claim, newest `as_of` first.
    public func claims() async throws -> [ClaimRecord] {
        try await database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT o.rowid, o.path, o.title, o.status,
                  (SELECT v_num FROM props WHERE obj = o.rowid AND key = 'confidence' LIMIT 1) AS confidence,
                  (SELECT coalesce(v_date, v_text) FROM props WHERE obj = o.rowid AND key = 'as_of' LIMIT 1) AS as_of,
                  (SELECT group_concat(tag, ' ') FROM tags WHERE obj = o.rowid) AS tags
                FROM objects o WHERE o.type = 'claim' ORDER BY as_of DESC, o.title
                """).map(Self.record)
        }
    }

    /// The supersedes chain through `path`, oldest first: what it replaced, and what replaced it.
    public func history(of path: String) async throws -> [ClaimRecord] {
        try await database.pool.read { db in
            guard let start = try Int64.fetchOne(db, sql: "SELECT rowid FROM objects WHERE path = ?", arguments: [path]) else { return [] }
            var older: [Int64] = []
            var newer: [Int64] = []
            var seen: Set<Int64> = [start]
            var frontier = [start]
            while let current = frontier.popLast() {
                for previous in try Int64.fetchAll(db, sql: "SELECT dst FROM links WHERE src = ? AND rel = 'supersedes' AND dst IS NOT NULL",
                                                   arguments: [current]) where seen.insert(previous).inserted {
                    older.append(previous)
                    frontier.append(previous)
                }
            }
            frontier = [start]
            while let current = frontier.popLast() {
                for next in try Int64.fetchAll(db, sql: "SELECT src FROM links WHERE dst = ? AND rel = 'supersedes'", arguments: [current])
                where seen.insert(next).inserted {
                    newer.append(next)
                    frontier.append(next)
                }
            }
            // Walks run outward from `start`, so the older list is newest-first.
            let ids = older.reversed() + [start] + newer
            let json = "[" + ids.map(String.init).joined(separator: ",") + "]"
            let records = try Row.fetchAll(db, sql: """
                SELECT o.rowid, o.path, o.title, o.status,
                  (SELECT v_num FROM props WHERE obj = o.rowid AND key = 'confidence' LIMIT 1) AS confidence,
                  (SELECT coalesce(v_date, v_text) FROM props WHERE obj = o.rowid AND key = 'as_of' LIMIT 1) AS as_of,
                  (SELECT group_concat(tag, ' ') FROM tags WHERE obj = o.rowid) AS tags
                FROM objects o WHERE o.rowid IN (SELECT value FROM json_each(?))
                """, arguments: [json]).map { (rowid: $0["rowid"] as Int64, record: Self.record($0)) }
            let position = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return records.sorted { (position[$0.rowid] ?? 0) < (position[$1.rowid] ?? 0) }.map(\.record)
        }
    }

    static func record(_ row: Row) -> ClaimRecord {
        let tags: String? = row["tags"]
        return ClaimRecord(path: row["path"], title: row["title"], status: ClaimStatus(rawValue: row["status"] ?? "") ?? .held,
                           confidence: row["confidence"], asOf: row["as_of"],
                           tags: tags?.split(separator: " ").map(String.init) ?? [])
    }

    // MARK: Helpers

    func create(_ text: String, sources: [String], supersedes: [String], confidence: Double, now: Date) async throws -> String {
        let stem = NoteFileName.make(ClaimNote.title(for: text))
        var path = "\(Self.folder)/\(stem).md"
        var counter = 2
        while FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) {
            path = "\(Self.folder)/\(stem) \(counter).md"
            counter += 1
        }
        try await writer.write(ClaimNote.render(text: text, sources: sources, supersedes: supersedes, confidence: confidence,
                                                date: Self.day(now, calendar)), to: path, as: .user)
        return path
    }

    /// The note's title when it names exactly one note, else its path without ".md".
    func linkTarget(for path: String) async throws -> String {
        let title = NoteParser.title(for: path)
        let count = try await database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM objects WHERE name_key = ?", arguments: [title.lowercased()]) ?? 0
        }
        return count <= 1 ? title : String(path.dropLast(3))
    }

    static func day(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// File names for notes granite creates (same rules as `KBCapture.NoteFactory`).
public enum NoteFileName {
    public static func make(_ title: String) -> String {
        let forbidden = Set("/\\:*?\"<>|#^[]")
        var cleaned = String(title.map { forbidden.contains($0) || $0.isNewline ? " " : $0 })
        while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = String(cleaned.prefix(120)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
