import Foundation
import GRDB
import KBCore

/// One thing the vault lint found. Deterministic: no model involved.
public struct LintIssue: Sendable, Hashable {
    public enum Rule: String, Sendable, CaseIterable {
        case unresolvedLink = "unresolved link"
        case orphan
        case missingProperty = "missing property"
        case staleClaim = "stale claim"
        case yamlError = "YAML error"
        case staleInbox = "stale inbox item"
        case aiOutsideAI = "AI text outside AI/"
        case uncitedAI = "uncited AI paragraph"
    }

    public let rule: Rule
    public let path: String
    public let line: Int?
    public let message: String

    public init(rule: Rule, path: String, line: Int? = nil, message: String) {
        self.rule = rule
        self.path = path
        self.line = line
        self.message = message
    }
}

/// Vault lint (master plan §7, idea 7): orphans, unresolved links, missing properties, held claims
/// whose `as_of` is over a year old, YAML errors, stale inbox items, AI text in the human layer,
/// and AI paragraphs without a citation.
public struct VaultLint: Sendable {
    public let database: IndexDatabase
    public var staleClaimDays = 365
    public var staleInboxDays = 14

    public init(database: IndexDatabase) {
        self.database = database
    }

    public func run(now: Date = Date()) throws -> [LintIssue] {
        try database.pool.read { db in
            var issues: [LintIssue] = []

            // Links to notes that don't exist (attachments and URLs are not notes).
            for row in try Row.fetchAll(db, sql: """
                SELECT o.path, l.line, l.target_text FROM links l JOIN objects o ON o.rowid = l.src
                WHERE l.dst IS NULL AND l.target_key != '' AND o.path NOT LIKE 'AI/%' ORDER BY o.path, l.line
                """) {
                let target: String = row["target_text"]
                let ext = (target as NSString).pathExtension.lowercased()
                guard ext.isEmpty || ext == "md", !target.contains("://") else { continue }
                issues.append(LintIssue(rule: .unresolvedLink, path: row["path"], line: row["line"],
                                        message: "[[\(target)]] doesn't match any note"))
            }

            // Notes nothing links to and that link nowhere (your writing only).
            for path in try String.fetchAll(db, sql: """
                SELECT o.path FROM objects o
                WHERE o.type IN ('note', 'claim', 'decision') AND o.path NOT LIKE 'Inbox/%' AND o.path NOT LIKE 'AI/%'
                  AND o.path NOT LIKE 'Daily/%' AND o.path NOT LIKE 'Archive/%'
                  AND NOT EXISTS (SELECT 1 FROM links l WHERE l.src = o.rowid)
                  AND NOT EXISTS (SELECT 1 FROM links l JOIN objects s ON s.rowid = l.src
                                  WHERE l.dst = o.rowid AND s.path NOT LIKE 'AI/%')
                ORDER BY o.path
                """) {
                issues.append(LintIssue(rule: .orphan, path: path, message: "no links in or out"))
            }

            // Claims need status, confidence and as_of; sources need a kind.
            for row in try Row.fetchAll(db, sql: """
                SELECT o.path, o.type, o.status, o.kind,
                  EXISTS(SELECT 1 FROM props p WHERE p.obj = o.rowid AND p.key = 'confidence') AS has_confidence,
                  EXISTS(SELECT 1 FROM props p WHERE p.obj = o.rowid AND p.key = 'as_of') AS has_as_of
                FROM objects o WHERE o.type IN ('claim', 'source') AND o.path NOT LIKE 'Papers/text/%' ORDER BY o.path
                """) {
                let path: String = row["path"]
                let type: String = row["type"]
                var missing: [String] = []
                if type == "claim" {
                    if (row["status"] as String?) == nil { missing.append("status") }
                    if !(row["has_confidence"] as Bool) { missing.append("confidence") }
                    if !(row["has_as_of"] as Bool) { missing.append("as_of") }
                } else if (row["kind"] as String?) == nil {
                    missing.append("kind")
                }
                if !missing.isEmpty {
                    issues.append(LintIssue(rule: .missingProperty, path: path, line: 1, message: "missing \(missing.joined(separator: ", "))"))
                }
            }

            // Held claims you haven't reconsidered in a year.
            let cutoff = Self.day(now.addingTimeInterval(-Double(staleClaimDays) * 86_400))
            for row in try Row.fetchAll(db, sql: """
                SELECT o.path, coalesce(p.v_date, p.v_text) AS as_of FROM objects o JOIN props p ON p.obj = o.rowid AND p.key = 'as_of'
                WHERE o.type = 'claim' AND o.status = 'held' AND coalesce(p.v_date, p.v_text) < ? ORDER BY as_of
                """, arguments: [cutoff]) {
                let asOf: String = row["as_of"]
                issues.append(LintIssue(rule: .staleClaim, path: row["path"], line: 1, message: "held since \(asOf): still true?"))
            }

            for row in try Row.fetchAll(db, sql: "SELECT path, yaml_error FROM objects WHERE yaml_error IS NOT NULL ORDER BY path") {
                issues.append(LintIssue(rule: .yamlError, path: row["path"], line: 1, message: row["yaml_error"]))
            }

            let inboxCutoff = now.addingTimeInterval(-Double(staleInboxDays) * 86_400).timeIntervalSinceReferenceDate
            for row in try Row.fetchAll(db, sql: """
                SELECT path, mtime FROM objects WHERE path LIKE 'Inbox/%' AND mtime < ? ORDER BY mtime
                """, arguments: [inboxCutoff]) {
                let days = Int((now.timeIntervalSinceReferenceDate - (row["mtime"] as Double)) / 86_400)
                issues.append(LintIssue(rule: .staleInbox, path: row["path"], message: "\(days) days in the inbox: make a note, append or archive"))
            }

            // AI-written files belong in AI/; anything else must come through an accepted proposal.
            for path in try String.fetchAll(db, sql: "SELECT path FROM objects WHERE origin = 'ai' AND path NOT LIKE 'AI/%' ORDER BY path") {
                issues.append(LintIssue(rule: .aiOutsideAI, path: path, line: 1, message: "origin: ai outside AI/ with no acceptance record"))
            }

            // AI syntheses and digests: every paragraph should cite something.
            for row in try Row.fetchAll(db, sql: """
                SELECT o.path, b.start_line, b.text FROM blocks b JOIN objects o ON o.rowid = b.obj
                WHERE o.path LIKE 'AI/Synthesis/%' AND b.kind = 'paragraph' AND length(b.text) > 80
                  AND b.text NOT LIKE '%[[%' AND b.text NOT LIKE '%](%' ORDER BY o.path, b.start_line
                """) {
                issues.append(LintIssue(rule: .uncitedAI, path: row["path"], line: row["start_line"], message: "no citation in this paragraph"))
            }
            return issues
        }
    }

    static func day(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
