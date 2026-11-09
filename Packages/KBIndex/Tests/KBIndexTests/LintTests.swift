import Foundation
import KBCore
import Testing
@testable import KBIndex

@Suite struct LintTests {
    @Test func findsEachKindOfIssue() async throws {
        let temp = try TempVault()
        try temp.put("Notes/Linked.md", "See [[Missing note]] and ![[diagram.png]] and [[Target]].\n")
        try temp.put("Notes/Target.md", "Linked to.\n")
        try temp.put("Notes/Lonely.md", "Nothing links here.\n")
        try temp.put("Notes/Old claim.md", "---\ntype: claim\nstatus: held\nconfidence: 0.5\nas_of: 2024-01-01\n---\nOld [[Target]].\n")
        try temp.put("Notes/Bare claim.md", "---\ntype: claim\n---\nNo status [[Target]].\n")
        try temp.put("Notes/Broken.md", "---\ntitle: [unclosed\n---\nBody [[Target]]\n")
        try temp.put("Notes/Smuggled.md", "---\norigin: ai\n---\nWritten by a model [[Target]].\n")
        try temp.put("Inbox/2026-10-01 0900.md", "old capture\n")
        try temp.put("AI/Digests/2026-11-08.md", "---\ntype: digest\n---\nMentions [[Lonely]].\n")
        try temp.put("AI/Synthesis/summary.md", "A long synthesized paragraph that makes several claims about retrieval without citing a single note anywhere.\n\nThis one cites [[Target]] properly and is also long enough to count here.\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let old = temp.root.appending(path: "Inbox/2026-10-01 0900.md")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_790_000_000)], ofItemAtPath: old.path(percentEncoded: false))
        _ = try await indexer.update(paths: ["Inbox/2026-10-01 0900.md"])

        let now = Date(timeIntervalSince1970: 1_794_214_925)  // 2026-11-09
        let issues = try VaultLint(database: database).run(now: now)
        func paths(_ rule: LintIssue.Rule) -> [String] { issues.filter { $0.rule == rule }.map(\.path) }
        #expect(paths(.unresolvedLink) == ["Notes/Linked.md"])
        #expect(issues.first { $0.rule == .unresolvedLink }?.message == "[[Missing note]] doesn't match any note")
        #expect(paths(.orphan) == ["Notes/Lonely.md"])
        #expect(paths(.missingProperty) == ["Notes/Bare claim.md"])
        #expect(issues.first { $0.rule == .missingProperty }?.message == "missing status, confidence, as_of")
        #expect(paths(.staleClaim) == ["Notes/Old claim.md"])
        #expect(paths(.yamlError) == ["Notes/Broken.md"])
        #expect(paths(.staleInbox) == ["Inbox/2026-10-01 0900.md"])
        #expect(paths(.aiOutsideAI) == ["Notes/Smuggled.md"])
        #expect(issues.filter { $0.rule == .uncitedAI }.map(\.line) == [1])
    }
}

@Suite struct ClaimTouchTests {
    @Test func newSourcesNearHeldClaims() async throws {
        let temp = try TempVault()
        try temp.put("Notes/Car claim.md", "---\ntype: claim\nstatus: held\n---\nmy car needs new brakes\n")
        try temp.put("Notes/Old claim.md", "---\ntype: claim\nstatus: superseded\n---\nmy car needs new brakes\n")
        try temp.put("Papers/garage.md", "---\ntype: source\nkind: paper\n---\nthe automobile needs new brakes\n")
        try temp.put("Papers/cooking.md", "---\ntype: source\nkind: paper\n---\nrecipes for bread and soup\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        _ = try await EmbeddingJob(database: database, embedder: FakeEmbedder()).run()
        let touches = try ClaimTouches.find(in: database, sourcesSince: .distantPast, threshold: 0.6)
        #expect(touches.map(\.source) == ["Papers/garage.md"] && touches.first?.claim == "Notes/Car claim.md")
        #expect(try ClaimTouches.find(in: database, sourcesSince: Date().addingTimeInterval(3600)).isEmpty)
    }
}

@Suite struct TrailSuggesterTests {
    @Test func chainsFollowLinksWithoutRepeats() async throws {
        let temp = try TempVault()
        try temp.put("Notes/A.md", "Start: see [[B]].\n")
        try temp.put("Notes/B.md", "Then [[C]].\n")
        try temp.put("Notes/C.md", "Then [[D]] and back to [[A]].\n")
        try temp.put("Notes/D.md", "End.\n")
        try temp.put("Notes/X.md", "Only [[Y]].\n")
        try temp.put("Notes/Y.md", "Short.\n")
        try temp.put("Papers/p.md", "---\ntype: source\nkind: paper\ndoi: 10.1/ABC\n---\nPaper.\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let chains = try TrailSuggester.chains(in: database, since: .distantPast)
        #expect(chains == [["Notes/A.md", "Notes/B.md", "Notes/C.md", "Notes/D.md"]])
        #expect(try database.knownDOIs() == ["10.1/abc"])
    }
}
