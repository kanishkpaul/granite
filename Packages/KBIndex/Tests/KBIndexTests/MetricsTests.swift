import Foundation
import KBCore
import Testing
@testable import KBIndex

@Suite struct MetricsTests {
    @Test func computesFromIndexStateAndExternals() async throws {
        let temp = try TempVault()
        let today = VaultMetrics.day(Date())
        try temp.put("Notes/Mine.md", "my writing\n")
        try temp.put("Notes/Essay.md", "---\nkind: output\n---\nan essay\n")
        try temp.put("Daily/2026-W46.md", "---\ntype: daily\nkind: weekly\n---\nanswers\n")
        try temp.put("Papers/p.md", "---\ntype: source\nkind: paper\n---\npaper\n")
        try temp.put("Notes/Claim.md", "---\ntype: claim\nstatus: superseded\ncreated: \(today)\nas_of: \(today)\n---\nold view\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let state = try StateDatabase(url: temp.root.deletingLastPathComponent().appending(path: "state.sqlite"))
        let search = try state.recordSearch(query: "x", mode: "bm25", results: 3)
        try state.recordOpen(searchID: search, path: "Notes/Mine.md", rank: 1, msToOpen: 4_000)
        _ = try state.recordSearch(query: "y", mode: "bm25", results: 0)
        let qa = try state.recordQA(route: "on-device", mode: "tellMe", abstained: true, sentences: 4, verified: 3)
        try state.markAbstention(qaID: qa, correct: true)
        try state.record(feature: "see-also", action: .shown)
        try state.record(feature: "see-also", action: .accepted)
        try state.record(AuditEntry(route: "haiku", model: "claude-haiku-5-5", task: "qa", label: "local", inputTokens: 1, outputTokens: 1,
                                    usd: 0.01, notePaths: ["Inbox/a.md"], promptHash: "h", outcome: "ok"))

        let metrics = try VaultMetrics(database: database, state: state).compute(external: ExternalMeasures(
            linesAdded: ["Notes/Mine.md": 30, "Papers/p.md": 90, "AI/Digests/d.md": 500], recall: 0.9, reviews: 10, inboxMedianDays: 20))
        func metric(_ key: String) throws -> Metric { try #require(metrics.first { $0.key == key }) }
        #expect(try metric("own_notes_30d").value == "3 notes · 1 new claims")
        #expect(try metric("inflow_human_share").number == 0.25 && metric("inflow_human_share").health == .good)
        #expect(try metric("output_per_input").value == "1 outputs / 1 sources")
        #expect(try metric("refind_success").number == 0.5)
        #expect(try metric("correct_abstention").number == 1 && metric("citation_pass_rate").number == 0.75)
        #expect(try metric("acceptance_see-also").number == 1)
        #expect(try metric("egress_cloud_calls").health == .alarm, "a local note on a cloud route")
        #expect(try metric("retention").health == .good && metric("belief_motion").number == 1)
        #expect(try metric("inbox_median_days").health == .alarm)
        #expect(try metric("weekly_reviews_4w").value == "1 of 4")

        let text = try VaultMetrics(database: database, state: state).freeze(metrics, week: "2026-W46")
        #expect(text.contains("| Own notes written (30 days) | 3 notes · 1 new claims |") && text.contains("**alarm**"))
        #expect(try state.metrics(week: "2026-W46")["retention"] == 0.9)
    }
}
