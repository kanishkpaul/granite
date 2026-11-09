import Foundation
import GRDB

/// `state.sqlite`: not knowledge, but worth keeping (master plan §4.6). Audit log of every model
/// call, feature events (shown / accepted / rejected), search events, Q&A log, weekly metrics.
/// Unlike `index.sqlite` it is never rebuilt: schema changes are migrations.
public final class StateDatabase: Sendable {
    public let pool: DatabasePool

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        pool = try DatabasePool(path: url.path(percentEncoded: false), configuration: configuration)
        try Self.migrator.migrate(pool)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
            CREATE TABLE audit(
              id INTEGER PRIMARY KEY,
              ts REAL NOT NULL,
              route TEXT NOT NULL,
              model TEXT NOT NULL,
              task TEXT NOT NULL,
              label TEXT NOT NULL,
              in_tok INTEGER NOT NULL,
              out_tok INTEGER NOT NULL,
              usd REAL NOT NULL,
              note_paths TEXT NOT NULL,
              prompt_hash TEXT NOT NULL,
              outcome TEXT NOT NULL
            );
            CREATE INDEX audit_ts ON audit(ts);

            CREATE TABLE feature_events(
              id INTEGER PRIMARY KEY,
              ts REAL NOT NULL,
              feature TEXT NOT NULL,
              action TEXT NOT NULL,
              target TEXT
            );
            CREATE INDEX feature_events_feature ON feature_events(feature, ts);

            CREATE TABLE search_events(
              id INTEGER PRIMARY KEY,
              ts REAL NOT NULL,
              query TEXT NOT NULL,
              mode TEXT NOT NULL,
              results INTEGER NOT NULL,
              opened_path TEXT,
              rank INTEGER,
              ms_to_open REAL
            );

            CREATE TABLE qa_log(
              id INTEGER PRIMARY KEY,
              ts REAL NOT NULL,
              route TEXT NOT NULL,
              mode TEXT NOT NULL,
              abstained INTEGER NOT NULL,
              sentences INTEGER NOT NULL,
              verified INTEGER NOT NULL,
              abstention_correct INTEGER
            );

            CREATE TABLE metrics(
              week TEXT NOT NULL,
              key TEXT NOT NULL,
              value REAL NOT NULL,
              PRIMARY KEY(week, key)
            );
            """)
        }
        return migrator
    }
}

// MARK: Audit

public struct AuditEntry: Sendable, Hashable {
    public var date: Date
    public var route: String
    public var model: String
    public var task: String
    public var label: String
    public var inputTokens: Int
    public var outputTokens: Int
    public var usd: Double
    /// Vault paths whose text was in the prompt. Never their content (master plan §6.6).
    public var notePaths: [String]
    public var promptHash: String
    public var outcome: String

    public init(date: Date = Date(), route: String, model: String, task: String, label: String, inputTokens: Int,
                outputTokens: Int, usd: Double, notePaths: [String], promptHash: String, outcome: String) {
        self.date = date
        self.route = route
        self.model = model
        self.task = task
        self.label = label
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.usd = usd
        self.notePaths = notePaths
        self.promptHash = promptHash
        self.outcome = outcome
    }
}

public struct EgressSummary: Sendable, Hashable {
    public let route: String
    public let calls: Int
    public let notes: Int
    public let usd: Double
}

extension StateDatabase {
    public func record(_ entry: AuditEntry) throws {
        let paths = String(decoding: try JSONEncoder().encode(entry.notePaths), as: UTF8.self)
        try pool.write { db in
            try db.execute(sql: """
                INSERT INTO audit(ts, route, model, task, label, in_tok, out_tok, usd, note_paths, prompt_hash, outcome)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [entry.date.timeIntervalSinceReferenceDate, entry.route, entry.model, entry.task,
                                 entry.label, entry.inputTokens, entry.outputTokens, entry.usd, paths,
                                 entry.promptHash, entry.outcome])
        }
    }

    /// Dollars spent since the start of `date`'s calendar month (local time).
    public func spend(inMonthOf date: Date = Date(), calendar: Calendar = .current) throws -> Double {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return try pool.read { db in
            try Double.fetchOne(db, sql: "SELECT coalesce(sum(usd), 0) FROM audit WHERE ts >= ?",
                                arguments: [start.timeIntervalSinceReferenceDate]) ?? 0
        }
    }

    /// "What left this Mac": calls, distinct notes and dollars per route since `since`.
    public func egress(since: Date) throws -> [EgressSummary] {
        try pool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT route, count(*) AS calls, sum(usd) AS usd, group_concat(note_paths, char(31)) AS paths
                FROM audit WHERE ts >= ? GROUP BY route ORDER BY route
                """, arguments: [since.timeIntervalSinceReferenceDate])
            return rows.map { row in
                let joined: String = row["paths"] ?? ""
                var notes = Set<String>()
                for chunk in joined.split(separator: "\u{1F}") {
                    if let list = try? JSONDecoder().decode([String].self, from: Data(chunk.utf8)) { notes.formUnion(list) }
                }
                return EgressSummary(route: row["route"], calls: row["calls"], notes: notes.count, usd: row["usd"] ?? 0)
            }
        }
    }

    public func recentAudit(limit: Int = 100) throws -> [AuditEntry] {
        try pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM audit ORDER BY ts DESC LIMIT ?", arguments: [limit]).map { row in
                let paths = (try? JSONDecoder().decode([String].self, from: Data((row["note_paths"] as String).utf8))) ?? []
                return AuditEntry(date: Date(timeIntervalSinceReferenceDate: row["ts"]), route: row["route"],
                                  model: row["model"], task: row["task"], label: row["label"], inputTokens: row["in_tok"],
                                  outputTokens: row["out_tok"], usd: row["usd"], notePaths: paths,
                                  promptHash: row["prompt_hash"], outcome: row["outcome"])
            }
        }
    }
}

// MARK: Feature events (acceptance tracking, auto-pause)

public enum FeatureAction: String, Sendable, CaseIterable {
    case shown, accepted, edited, rejected
}

extension StateDatabase {
    public func record(feature: String, action: FeatureAction, target: String? = nil, date: Date = Date()) throws {
        try pool.write { db in
            try db.execute(sql: "INSERT INTO feature_events(ts, feature, action, target) VALUES (?, ?, ?, ?)",
                           arguments: [date.timeIntervalSinceReferenceDate, feature, action.rawValue, target])
        }
    }

    /// (accepted + edited) ÷ shown since `since`, with the number shown. nil rate when nothing was shown.
    public func acceptance(feature: String, since: Date) throws -> (rate: Double?, shown: Int) {
        try pool.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT sum(action = 'shown') AS shown, sum(action IN ('accepted', 'edited')) AS taken
                FROM feature_events WHERE feature = ? AND ts >= ?
                """, arguments: [feature, since.timeIntervalSinceReferenceDate])
            let shown: Int = row?["shown"] ?? 0
            let taken: Int = row?["taken"] ?? 0
            return (shown > 0 ? Double(taken) / Double(shown) : nil, shown)
        }
    }
}

/// When an AI feature stops itself (master plan §6.4, §7): at least `minimumShown` suggestions in
/// `window`, and under `pauseBelow` of them accepted or edited.
public enum FeatureGuard {
    public static let pauseBelow = 0.10
    public static let window: TimeInterval = 28 * 86_400
    public static let minimumShown = 20
}

extension StateDatabase {
    public func isPaused(feature: String, now: Date = Date()) throws -> Bool {
        let (rate, shown) = try acceptance(feature: feature, since: now.addingTimeInterval(-FeatureGuard.window))
        guard let rate, shown >= FeatureGuard.minimumShown else { return false }
        return rate < FeatureGuard.pauseBelow
    }
}

// MARK: Search and Q&A logs, metrics

extension StateDatabase {
    @discardableResult
    public func recordSearch(query: String, mode: String, results: Int, date: Date = Date()) throws -> Int64 {
        try pool.write { db in
            try db.execute(sql: "INSERT INTO search_events(ts, query, mode, results) VALUES (?, ?, ?, ?)",
                           arguments: [date.timeIntervalSinceReferenceDate, query, mode, results])
            return db.lastInsertedRowID
        }
    }

    public func recordOpen(searchID: Int64, path: String, rank: Int, msToOpen: Double) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE search_events SET opened_path = ?, rank = ?, ms_to_open = ? WHERE id = ? AND opened_path IS NULL",
                           arguments: [path, rank, msToOpen, searchID])
        }
    }

    @discardableResult
    public func recordQA(route: String, mode: String, abstained: Bool, sentences: Int, verified: Int,
                         date: Date = Date()) throws -> Int64 {
        try pool.write { db in
            try db.execute(sql: """
                INSERT INTO qa_log(ts, route, mode, abstained, sentences, verified) VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [date.timeIntervalSinceReferenceDate, route, mode, abstained, sentences, verified])
            return db.lastInsertedRowID
        }
    }

    /// You mark an abstention ("I have no note on that") right or wrong.
    public func markAbstention(qaID: Int64, correct: Bool) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE qa_log SET abstention_correct = ? WHERE id = ?", arguments: [correct, qaID])
        }
    }

    public func setMetric(week: String, key: String, value: Double) throws {
        try pool.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO metrics(week, key, value) VALUES (?, ?, ?)", arguments: [week, key, value])
        }
    }

    public func metrics(week: String) throws -> [String: Double] {
        try pool.read { db in
            Dictionary(uniqueKeysWithValues: try Row.fetchAll(db, sql: "SELECT key, value FROM metrics WHERE week = ?",
                                                              arguments: [week]).map { ($0["key"] as String, $0["value"] as Double) })
        }
    }
}
