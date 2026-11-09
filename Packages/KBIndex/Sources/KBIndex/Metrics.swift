import Foundation
import GRDB
import KBCore

/// One row of the dashboard (master plan §11).
public struct Metric: Sendable, Equatable, Identifiable {
    public enum Health: String, Sendable { case good, watch, alarm, unknown }

    public let key: String
    public let name: String
    public let value: String
    /// The number stored in `state.sqlite` `metrics` for trends (nil when not measured yet).
    public let number: Double?
    public let healthy: String
    public let health: Health
    public var id: String { key }
}

/// Numbers granite can't get from the index or state database alone; the app fills them in.
public struct ExternalMeasures: Sendable {
    /// Lines added per file in the last 30 days (git).
    public var linesAdded: [String: Int]?
    /// FSRS recall on reviews in the last 7 days, and how many.
    public var recall: Double?
    public var reviews: Int = 0
    /// Median inbox age in days.
    public var inboxMedianDays: Double?

    public init(linesAdded: [String: Int]? = nil, recall: Double? = nil, reviews: Int = 0, inboxMedianDays: Double? = nil) {
        self.linesAdded = linesAdded
        self.recall = recall
        self.reviews = reviews
        self.inboxMedianDays = inboxMedianDays
    }
}

/// Measuring the edge (§11): own writing, inflow mix, output, re-find, abstention, proposal
/// acceptance, citations, retention, belief motion, backlog and egress. Frozen weekly to
/// `AI/Metrics/YYYY-Www.md` so you, agents and git can read them as text.
public struct VaultMetrics: Sendable {
    public let database: IndexDatabase
    public let state: StateDatabase?

    public init(database: IndexDatabase, state: StateDatabase?) {
        self.database = database
        self.state = state
    }

    public func compute(now: Date = Date(), external: ExternalMeasures = ExternalMeasures()) throws -> [Metric] {
        let month = now.addingTimeInterval(-30 * 86_400)
        let quarter = now.addingTimeInterval(-91 * 86_400)
        let week = now.addingTimeInterval(-7 * 86_400)
        var metrics: [Metric] = []

        let index = try database.pool.read { db -> (own: Int, claims: Int, outputs: Int, sources: Int, motion: Int, origins: [String: String]) in
            let monthStart = Self.day(month), quarterStart = Self.day(quarter)
            let own = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects WHERE type IN ('note', 'claim', 'decision') AND origin = 'human'
                  AND path NOT LIKE 'AI/%' AND path NOT LIKE 'Inbox/%' AND mtime >= ?
                """, arguments: [month.timeIntervalSinceReferenceDate]) ?? 0
            let claims = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects WHERE type = 'claim' AND coalesce(created, '') >= ?
                """, arguments: [monthStart]) ?? 0
            let outputs = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects WHERE kind = 'output' AND (coalesce(created, '') >= ? OR mtime >= ?)
                """, arguments: [quarterStart, quarter.timeIntervalSinceReferenceDate]) ?? 0
            let sources = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects WHERE type IN ('source', 'clipping') AND path NOT LIKE 'Papers/text/%'
                  AND (coalesce(created, '') >= ? OR mtime >= ?)
                """, arguments: [quarterStart, quarter.timeIntervalSinceReferenceDate]) ?? 0
            let motion = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects o JOIN props p ON p.obj = o.rowid AND p.key = 'as_of'
                WHERE o.type = 'claim' AND o.status IN ('superseded', 'revised') AND coalesce(p.v_date, p.v_text) >= ?
                """, arguments: [quarterStart]) ?? 0
            var origins: [String: String] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT path, origin FROM objects") { origins[row["path"]] = row["origin"] }
            return (own, claims, outputs, sources, motion, origins)
        }

        metrics.append(Metric(key: "own_notes_30d", name: "Own notes written (30 days)",
                              value: "\(index.own) notes · \(index.claims) new claims", number: Double(index.own),
                              healthy: "steady or rising; ≥ 8 claims a month early on",
                              health: index.claims >= 8 ? .good : (index.own > 0 ? .watch : .alarm)))

        if let lines = external.linesAdded {
            var byOrigin: [String: Int] = [:]
            for (path, count) in lines {
                let origin = path.hasPrefix("AI/") ? "ai" : (index.origins[path] ?? "human")
                byOrigin[origin, default: 0] += count
            }
            let human = byOrigin["human", default: 0] + byOrigin["ai-accepted", default: 0]
            let nonAI = human + byOrigin["source", default: 0]
            let share = nonAI > 0 ? Double(human) / Double(nonAI) : nil
            let mix = ["human", "source", "ai", "ai-accepted"].compactMap { key in byOrigin[key].map { "\(key) \($0)" } }
            metrics.append(Metric(key: "inflow_human_share", name: "Inflow mix (lines added, 30 days)",
                                  value: (mix.isEmpty ? "nothing committed" : mix.joined(separator: " · "))
                                      + (share.map { String(format: " · yours %.0f%%", $0 * 100) } ?? ""),
                                  number: share, healthy: "your words ≥ 25% of non-AI inflow; alarm below 10%",
                                  health: share.map { $0 >= 0.25 ? .good : ($0 >= 0.10 ? .watch : .alarm) } ?? .unknown))
        } else {
            metrics.append(Metric(key: "inflow_human_share", name: "Inflow mix", value: "needs git", number: nil,
                                  healthy: "your words ≥ 25% of non-AI inflow", health: .unknown))
        }

        let ratio = index.sources > 0 ? Double(index.outputs) / Double(index.sources) : nil
        metrics.append(Metric(key: "output_per_input", name: "Output per input (quarter)",
                              value: "\(index.outputs) outputs / \(index.sources) sources", number: ratio,
                              healthy: "nonzero every month (Luhmann: ~1%)", health: index.outputs > 0 ? .good : .watch))

        if let state {
            let refind = try state.pool.read { db -> (searches: Int, quick: Int, median: Double?) in
                let rows = try Row.fetchAll(db, sql: "SELECT rank, ms_to_open FROM search_events WHERE ts >= ?",
                                            arguments: [week.timeIntervalSinceReferenceDate])
                let opened = rows.compactMap { row -> Double? in
                    guard let rank: Int = row["rank"], rank <= 5, let ms: Double = row["ms_to_open"] else { return nil }
                    return ms
                }
                let quick = opened.filter { $0 <= 30_000 }.count
                let sorted = opened.sorted()
                return (rows.count, quick, sorted.isEmpty ? nil : sorted[sorted.count / 2])
            }
            let share = refind.searches > 0 ? Double(refind.quick) / Double(refind.searches) : nil
            metrics.append(Metric(key: "refind_success", name: "Re-find (7 days)",
                                  value: refind.searches == 0 ? "no searches"
                                      : String(format: "%d of %d searches opened a top-5 result in 30 s%@", refind.quick, refind.searches,
                                               refind.median.map { String(format: " · median %.0f s", $0 / 1000) } ?? ""),
                                  number: share, healthy: "time-to-refind under a minute; eval Recall@5 ≥ 0.8",
                                  health: share.map { $0 >= 0.5 ? .good : .watch } ?? .unknown))

            let qa = try state.pool.read { db -> (marked: Int, correct: Int, sentences: Int, verified: Int) in
                let row = try Row.fetchOne(db, sql: """
                    SELECT sum(abstention_correct IS NOT NULL) AS marked, sum(abstention_correct = 1) AS correct,
                           sum(sentences) AS sentences, sum(verified) AS verified FROM qa_log WHERE ts >= ?
                    """, arguments: [month.timeIntervalSinceReferenceDate])
                return (row?["marked"] ?? 0, row?["correct"] ?? 0, row?["sentences"] ?? 0, row?["verified"] ?? 0)
            }
            let abstention = qa.marked > 0 ? Double(qa.correct) / Double(qa.marked) : nil
            metrics.append(Metric(key: "correct_abstention", name: "Correct abstention (30 days)",
                                  value: qa.marked == 0 ? "none marked" : "\(qa.correct) of \(qa.marked) marked correct",
                                  number: abstention, healthy: "≥ 80%", health: abstention.map { $0 >= 0.8 ? .good : .watch } ?? .unknown))
            let citations = qa.sentences > 0 ? Double(qa.verified) / Double(qa.sentences) : nil
            metrics.append(Metric(key: "citation_pass_rate", name: "Citation pass rate (30 days)",
                                  value: qa.sentences == 0 ? "no answers yet" : "\(qa.verified) of \(qa.sentences) sentences verified",
                                  number: citations, healthy: "≥ 95%", health: citations.map { $0 >= 0.95 ? .good : .watch } ?? .unknown))

            let features = try state.pool.read { db in
                try String.fetchAll(db, sql: "SELECT DISTINCT feature FROM feature_events WHERE ts >= ? ORDER BY feature",
                                    arguments: [(now.addingTimeInterval(-FeatureGuard.window)).timeIntervalSinceReferenceDate])
            }
            for feature in features where feature != "weekly-review" {
                let (rate, shown) = try state.acceptance(feature: feature, since: now.addingTimeInterval(-FeatureGuard.window))
                let paused = try state.isPaused(feature: feature, now: now)
                metrics.append(Metric(key: "acceptance_\(feature)", name: "Acceptance: \(feature) (4 weeks)",
                                      value: rate.map { String(format: "%.0f%% of %d shown", $0 * 100, shown) } ?? "\(shown) shown"
                                          + (paused ? " · paused" : ""),
                                      number: rate, healthy: "pauses below 10%",
                                      health: paused ? .alarm : (rate.map { $0 >= 0.25 ? .good : .watch } ?? .unknown)))
            }

            let egress = try state.egress(since: week)
            let cloud = egress.filter { ["haiku", "sonnet", "opus"].contains($0.route) }
            let leaked = try state.pool.read { db in
                try Int.fetchOne(db, sql: """
                    SELECT count(*) FROM audit WHERE ts >= ? AND route IN ('haiku', 'sonnet', 'opus') AND label IN ('local', 'none', 'pcc')
                    """, arguments: [week.timeIntervalSinceReferenceDate]) ?? 0
            }
            metrics.append(Metric(key: "egress_cloud_calls", name: "Data egress (7 days)",
                                  value: cloud.isEmpty ? "nothing left this Mac"
                                      : cloud.map { "\($0.route): \($0.calls) calls, \($0.notes) notes, $\(String(format: "%.2f", $0.usd))" }
                                          .joined(separator: " · "),
                                  number: Double(cloud.reduce(0) { $0 + $1.calls }),
                                  healthy: "no local note ever on a cloud route", health: leaked > 0 ? .alarm : .good))
        }

        let weeklies = try database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM objects WHERE type = 'daily' AND kind = 'weekly' AND mtime >= ?",
                             arguments: [now.addingTimeInterval(-28 * 86_400).timeIntervalSinceReferenceDate]) ?? 0
        }
        metrics.append(Metric(key: "weekly_reviews_4w", name: "Weekly reviews (4 weeks)", value: "\(weeklies) of 4",
                              number: Double(weeklies), healthy: "4 in a row", health: weeklies >= 4 ? .good : (weeklies > 0 ? .watch : .alarm)))
        metrics.append(Metric(key: "retention", name: "Retention (7 days)",
                              value: external.recall.map { String(format: "%.0f%% recalled over %d reviews", $0 * 100, external.reviews) } ?? "no reviews",
                              number: external.recall, healthy: "about 85–90%",
                              health: external.recall.map { $0 >= 0.85 ? .good : .watch } ?? .unknown))
        metrics.append(Metric(key: "belief_motion", name: "Belief motion (quarter)", value: "\(index.motion) claims superseded or revised",
                              number: Double(index.motion), healthy: "> 0; zero for a year means changes of mind go unrecorded",
                              health: index.motion > 0 ? .good : .watch))
        metrics.append(Metric(key: "inbox_median_days", name: "Backlog age",
                              value: external.inboxMedianDays.map { String(format: "median %.0f days in the inbox", $0) } ?? "inbox empty",
                              number: external.inboxMedianDays, healthy: "under 14 days",
                              health: external.inboxMedianDays.map { $0 < 14 ? .good : .alarm } ?? .good))
        return metrics
    }

    /// Stores the numbers for trends and renders the weekly file.
    public func freeze(_ metrics: [Metric], week: String) throws -> String {
        for metric in metrics { if let number = metric.number { try state?.setMetric(week: week, key: metric.key, value: number) } }
        var lines = ["---", "type: digest", "kind: metrics", "origin: ai", "model: none", "ai: local", "week: \(week)", "---",
                     "# Metrics \(week)", "", "| Metric | This week | Healthy | |", "|---|---|---|---|"]
        for metric in metrics {
            let mark = switch metric.health {
            case .good: "✓"
            case .watch: "watch"
            case .alarm: "**alarm**"
            case .unknown: ""
            }
            lines.append("| \(metric.name) | \(metric.value.replacingOccurrences(of: "|", with: "/")) | \(metric.healthy) | \(mark) |")
        }
        lines += ["", "Computed by granite from the index, git and state.sqlite (master plan §11). No model involved.", ""]
        return lines.joined(separator: "\n")
    }

    static func day(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
