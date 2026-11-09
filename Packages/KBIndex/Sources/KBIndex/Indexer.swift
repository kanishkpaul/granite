import Foundation
import GRDB
import KBCore

public struct ReconcileReport: Sendable, CustomStringConvertible {
    public var scanned = 0
    public var parsed = 0
    /// mtime or size changed but the content hash did not (touch, atomic save of identical bytes).
    public var touched = 0
    public var removed = 0
    public var unchanged = 0
    public var seconds = 0.0

    public var description: String {
        "scanned \(scanned), parsed \(parsed), touched \(touched), removed \(removed), unchanged \(unchanged)"
            + String(format: " in %.2fs", seconds)
    }
}

/// Keeps `index.sqlite` in step with the vault. Change detection is mtime + size, then content hash.
/// Parsing runs in parallel; writes go in batched transactions; object rowids stay stable across
/// re-parses so links from other notes stay resolved.
public actor Indexer {
    public let database: IndexDatabase
    public let vault: Vault
    public let policy: VaultPolicy
    let batchSize: Int

    public init(database: IndexDatabase, vault: Vault, policy: VaultPolicy, batchSize: Int = 800) {
        self.database = database
        self.vault = vault
        self.policy = policy
        self.batchSize = batchSize
    }

    struct Existing: Sendable {
        let rowid: Int64
        let mtime: Double
        let size: Int
        let hash: Data
    }

    enum Outcome: Sendable {
        case parsed(ParsedNote, FileStat, rowid: Int64?)
        case touched(FileStat, rowid: Int64)
        case missing(String)
    }

    /// Full reconcile: stat-walk the vault, re-parse what changed, drop what disappeared.
    public func reconcile() async throws -> ReconcileReport {
        let clock = ContinuousClock()
        let start = clock.now
        var report = ReconcileReport()

        let files = vault.markdownFiles()
        report.scanned = files.count
        let existing = try await loadExisting()

        var pending: [(FileStat, Existing?)] = []
        var seen = Set<String>()
        for file in files {
            seen.insert(file.path)
            let known = existing[file.path]
            if let known, known.mtime == file.mtime, known.size == file.size {
                report.unchanged += 1
            } else {
                pending.append((file, known))
            }
        }
        let removed = existing.keys.filter { !seen.contains($0) }

        for batchStart in stride(from: 0, to: pending.count, by: batchSize) {
            let batch = Array(pending[batchStart..<min(batchStart + batchSize, pending.count)])
            let outcomes = await parse(batch)
            try await apply(outcomes, report: &report)
        }
        if !removed.isEmpty {
            try await database.pool.write { db in
                let statement = try db.cachedStatement(sql: "DELETE FROM objects WHERE path = ?")
                for path in removed { try statement.execute(arguments: [path]) }
            }
            report.removed = removed.count
        }
        try await resolveLinks()
        report.seconds = Self.seconds(clock.now - start)
        return report
    }

    /// Re-indexes specific vault-relative paths (from a file watcher). Missing files are removed.
    public func update(paths: [String]) async throws -> ReconcileReport {
        let clock = ContinuousClock()
        let start = clock.now
        var report = ReconcileReport()
        let existing = try await loadExisting(paths: paths)
        var batch: [(FileStat, Existing?)] = []
        var missing: [String] = []
        for path in Set(paths) {
            let url = vault.url(for: path)
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                missing.append(path)
                continue
            }
            let stat = FileStat(path: path, mtime: values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0,
                                size: values.fileSize ?? 0)
            batch.append((stat, existing[path]))
        }
        report.scanned = batch.count
        let outcomes = await parse(batch) + missing.map { Outcome.missing($0) }
        try await apply(outcomes, report: &report)
        try await resolveLinks()
        report.seconds = Self.seconds(clock.now - start)
        return report
    }

    func loadExisting(paths: [String]? = nil) async throws -> [String: Existing] {
        try await database.pool.read { db in
            var result: [String: Existing] = [:]
            let rows: [Row]
            if let paths {
                rows = try Row.fetchAll(db, sql: "SELECT rowid, path, mtime, size, hash FROM objects WHERE path IN (SELECT value FROM json_each(?))",
                                        arguments: [String(decoding: try JSONEncoder().encode(paths), as: UTF8.self)])
            } else {
                rows = try Row.fetchAll(db, sql: "SELECT rowid, path, mtime, size, hash FROM objects")
            }
            for row in rows {
                result[row["path"]] = Existing(rowid: row["rowid"], mtime: row["mtime"], size: row["size"], hash: row["hash"])
            }
            return result
        }
    }

    /// Reads and parses files on all cores. Files whose hash is unchanged come back as `.touched`.
    nonisolated func parse(_ batch: [(FileStat, Existing?)]) async -> [Outcome] {
        let workers = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let chunk = max(1, (batch.count + workers - 1) / workers)
        let vault = self.vault
        let policy = self.policy
        return await withTaskGroup(of: [Outcome].self) { group in
            for start in stride(from: 0, to: batch.count, by: chunk) {
                let slice = Array(batch[start..<min(start + chunk, batch.count)])
                group.addTask {
                    slice.map { stat, existing in
                        guard let data = try? Data(contentsOf: vault.url(for: stat.path)) else {
                            return .missing(stat.path)
                        }
                        let note = NoteParser.parse(data: data, path: stat.path, policy: policy)
                        if let existing, existing.hash == note.hash {
                            return .touched(stat, rowid: existing.rowid)
                        }
                        return .parsed(note, stat, rowid: existing?.rowid)
                    }
                }
            }
            var all: [Outcome] = []
            all.reserveCapacity(batch.count)
            for await part in group { all.append(contentsOf: part) }
            return all
        }
    }

    func apply(_ outcomes: [Outcome], report: inout ReconcileReport) async throws {
        let now = Date().timeIntervalSinceReferenceDate
        let counts = try await database.pool.write { db -> (parsed: Int, touched: Int, removed: Int) in
            var counts = (parsed: 0, touched: 0, removed: 0)
            for outcome in outcomes {
                switch outcome {
                case .parsed(let note, let stat, let rowid):
                    try Self.write(note, stat: stat, rowid: rowid, parsedAt: now, db: db)
                    counts.parsed += 1
                case .touched(let stat, let rowid):
                    try db.cachedStatement(sql: "UPDATE objects SET mtime = ?, size = ? WHERE rowid = ?")
                        .execute(arguments: [stat.mtime, stat.size, rowid])
                    counts.touched += 1
                case .missing(let path):
                    try db.cachedStatement(sql: "DELETE FROM objects WHERE path = ?").execute(arguments: [path])
                    counts.removed += 1
                }
            }
            return counts
        }
        report.parsed += counts.parsed
        report.touched += counts.touched
        report.removed += counts.removed
    }

    static func write(_ note: ParsedNote, stat: FileStat, rowid existing: Int64?, parsedAt: Double, db: Database) throws {
        let pathKey = LinkRef.key(for: note.path)
        let nameKey = note.title.lowercased()
        let objectArguments: StatementArguments = [
            note.id, note.path, pathKey, nameKey, note.type.rawValue, note.kind, note.origin.rawValue,
            note.aiLabel.rawValue, note.status, note.title, note.created, stat.mtime, note.size, note.hash,
            parsedAt, note.frontmatter?.error,
        ]
        let rowid: Int64
        if let existing {
            try db.cachedStatement(sql: """
                UPDATE objects SET id = ?, path = ?, path_key = ?, name_key = ?, type = ?, kind = ?, origin = ?,
                  ai_label = ?, status = ?, title = ?, created = ?, mtime = ?, size = ?, hash = ?, parsed_at = ?,
                  yaml_error = ? WHERE rowid = ?
                """).execute(arguments: objectArguments + [existing])
            // Its name or aliases may have changed: incoming links re-resolve in `resolveLinks`.
            try db.cachedStatement(sql: "UPDATE links SET dst = NULL WHERE dst = ? AND src != ?")
                .execute(arguments: [existing, existing])
            for table in ["aliases", "props", "tags", "links", "blocks"] {
                try db.cachedStatement(sql: "DELETE FROM \(table) WHERE \(table == "links" ? "src" : "obj") = ?")
                    .execute(arguments: [existing])
            }
            rowid = existing
        } else {
            try db.cachedStatement(sql: """
                INSERT INTO objects(id, path, path_key, name_key, type, kind, origin, ai_label, status, title,
                  created, mtime, size, hash, parsed_at, yaml_error)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """).execute(arguments: objectArguments)
            rowid = db.lastInsertedRowID
        }

        let alias = try db.cachedStatement(sql: "INSERT INTO aliases(obj, alias, alias_key) VALUES (?, ?, ?)")
        for name in note.aliases { try alias.execute(arguments: [rowid, name, name.lowercased()]) }

        let prop = try db.cachedStatement(sql: "INSERT INTO props(obj, key, v_text, v_num, v_date) VALUES (?, ?, ?, ?, ?)")
        for property in note.frontmatter?.properties ?? [] {
            let values: [PropertyValue] = if case .list(let items) = property.value { items } else { [property.value] }
            for value in values {
                switch value {
                case .number(let number):
                    try prop.execute(arguments: [rowid, property.key, value.text, number, nil])
                case .date(let date):
                    try prop.execute(arguments: [rowid, property.key, date, nil, date])
                case .string, .bool:
                    try prop.execute(arguments: [rowid, property.key, value.text, nil, nil])
                case .list, .map, .null:
                    continue
                }
            }
        }

        let tag = try db.cachedStatement(sql: "INSERT INTO tags(obj, tag, tag_key) VALUES (?, ?, ?)")
        for name in note.tags { try tag.execute(arguments: [rowid, name, name.lowercased()]) }

        let link = try db.cachedStatement(sql: """
            INSERT INTO links(src, target_text, target_key, rel, anchor_heading, anchor_block, alias, is_embed, syntax, line)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
        for ref in note.links {
            try link.execute(arguments: [rowid, ref.target, ref.targetKey, ref.relation, ref.heading, ref.blockID,
                                         ref.alias, ref.isEmbed, ref.syntax.rawValue, ref.line])
        }

        let block = try db.cachedStatement(sql: """
            INSERT INTO blocks(obj, block_id, kind, heading_path, start_line, end_line, text, origin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """)
        for item in note.blocks where !item.text.isEmpty {
            try block.execute(arguments: [rowid, item.blockID, item.kind.rawValue, item.headingPath, item.startLine,
                                          item.endLine, item.text, note.origin.rawValue])
        }
    }

    /// Resolves unresolved links the way Obsidian does, in order: self-link, exact vault path,
    /// file name (shortest path wins), path suffix ("folder/name"), alias.
    public func resolveLinks() async throws {
        try await database.pool.write { db in
            try db.execute(sql: """
            UPDATE links SET dst = src WHERE dst IS NULL AND target_key = '';
            UPDATE links SET dst = (SELECT o.rowid FROM objects o WHERE o.path_key = links.target_key LIMIT 1)
              WHERE dst IS NULL AND target_key != '';
            UPDATE links SET dst = (SELECT o.rowid FROM objects o WHERE o.name_key = links.target_key
                                    ORDER BY length(o.path), o.path LIMIT 1)
              WHERE dst IS NULL AND target_key != '' AND instr(target_key, '/') = 0;
            UPDATE links SET dst = (SELECT o.rowid FROM objects o
                                    WHERE o.name_key = substr(links.target_key, length(rtrim(links.target_key, replace(links.target_key, '/', ''))) + 1)
                                      AND o.path_key LIKE '%/' || links.target_key
                                    ORDER BY length(o.path) LIMIT 1)
              WHERE dst IS NULL AND instr(target_key, '/') > 0;
            UPDATE links SET dst = (SELECT a.obj FROM aliases a WHERE a.alias_key = links.target_key LIMIT 1)
              WHERE dst IS NULL AND target_key != '';
            """)
        }
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
