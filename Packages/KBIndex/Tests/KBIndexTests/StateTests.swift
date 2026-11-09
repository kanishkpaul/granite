import Foundation
import Testing
@testable import KBIndex

@Suite struct StateDatabaseTests {
    func database() throws -> StateDatabase {
        try StateDatabase(url: FileManager.default.temporaryDirectory.appending(path: "granite-state-\(UUID().uuidString)/state.sqlite"))
    }

    @Test func auditSpendAndEgress() throws {
        let state = try database()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let november = Date(timeIntervalSince1970: 1_794_214_925)  // 2026-11-09
        let october = Date(timeIntervalSince1970: 1_791_000_000)    // 2026-10-03
        try state.record(AuditEntry(date: october, route: "haiku", model: "claude-haiku-5-5", task: "qa", label: "cloud",
                                    inputTokens: 1000, outputTokens: 100, usd: 1.5, notePaths: ["Notes/a.md"],
                                    promptHash: "x", outcome: "ok"))
        try state.record(AuditEntry(date: november, route: "haiku", model: "claude-haiku-5-5", task: "qa", label: "cloud",
                                    inputTokens: 1000, outputTokens: 100, usd: 0.25, notePaths: ["Notes/a.md", "Notes/b.md"],
                                    promptHash: "y", outcome: "ok"))
        try state.record(AuditEntry(date: november, route: "on-device", model: "apple", task: "tagging", label: "local",
                                    inputTokens: 10, outputTokens: 5, usd: 0, notePaths: ["Inbox/c.md"], promptHash: "z",
                                    outcome: "ok"))
        #expect(try state.spend(inMonthOf: november, calendar: calendar) == 0.25)
        let egress = try state.egress(since: october.addingTimeInterval(-1))
        #expect(egress.map(\.route) == ["haiku", "on-device"])
        #expect(egress[0].calls == 2 && egress[0].notes == 2 && egress[0].usd == 1.75)
        #expect(try state.recentAudit(limit: 1).first?.task == "tagging")
    }

    @Test func acceptanceRate() throws {
        let state = try database()
        let now = Date()
        for _ in 0..<10 { try state.record(feature: "related", action: .shown, date: now) }
        try state.record(feature: "related", action: .accepted, date: now)
        try state.record(feature: "related", action: .edited, date: now)
        try state.record(feature: "related", action: .rejected, date: now)
        let (rate, shown) = try state.acceptance(feature: "related", since: now.addingTimeInterval(-60))
        #expect(shown == 10 && rate == 0.2)
        #expect(try state.acceptance(feature: "other", since: .distantPast).rate == nil)
    }

    @Test func searchQAAndMetrics() throws {
        let state = try database()
        let id = try state.recordSearch(query: "hybrid", mode: "bm25", results: 4)
        try state.recordOpen(searchID: id, path: "Notes/a.md", rank: 1, msToOpen: 1200)
        try state.recordOpen(searchID: id, path: "Notes/b.md", rank: 3, msToOpen: 3000)
        let opened = try state.pool.read { db in try String.fetchOne(db, sql: "SELECT opened_path FROM search_events") }
        #expect(opened == "Notes/a.md", "only the first open counts")
        let qa = try state.recordQA(route: "on-device", mode: "answer", abstained: true, sentences: 0, verified: 0)
        try state.markAbstention(qaID: qa, correct: true)
        try state.setMetric(week: "2026-W45", key: "claims_written", value: 3)
        try state.setMetric(week: "2026-W45", key: "claims_written", value: 4)
        #expect(try state.metrics(week: "2026-W45") == ["claims_written": 4])
        // Reopening applies no migration twice.
        _ = try StateDatabase(url: URL(filePath: state.pool.path))
    }
}
