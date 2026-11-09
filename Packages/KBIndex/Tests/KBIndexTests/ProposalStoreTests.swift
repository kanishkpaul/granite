import Foundation
import KBCore
import Testing
@testable import KBIndex

@Suite struct ProposalStoreTests {
    let now = Date(timeIntervalSince1970: 1_794_214_925)  // 2026-11-09
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    func store(_ temp: TempVault) async throws -> (ProposalStore, StateDatabase) {
        try temp.put("Notes/Hybrid retrieval.md", "# Hybrid\nRerankers matter.\n")
        try temp.put("Notes/Contextual BM25.md", "BM25 with context.\n")
        let (_, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let state = try StateDatabase(url: temp.root.deletingLastPathComponent().appending(path: "support/state.sqlite"))
        return (ProposalStore(indexer: indexer, writer: SafeWriter(vault: temp.vault), state: state, calendar: utc), state)
    }

    func link(_ target: String = "[[Hybrid retrieval]]", to: String = "Contextual BM25") -> Proposal {
        Proposal(kind: .link, target: target, feature: "see-also", model: "on-device", rationale: "Same mechanism.\nTwice.",
                 change: ProposalChange(added: ["- [[\(to)]] — same mechanism"]), created: "")
    }

    func read(_ temp: TempVault, _ path: String) throws -> String {
        try String(contentsOf: temp.root.appending(path: path), encoding: .utf8)
    }

    @Test func createListAccept() async throws {
        let temp = try TempVault()
        let (store, state) = try await store(temp)
        let path = try await store.create(link(), now: now)
        #expect(path.hasPrefix("AI/Proposals/2026-11-09 ") && path.hasSuffix(" link Hybrid retrieval.md"))
        #expect(try await store.open().map(\.path) == [path])
        #expect(try read(temp, path).contains("Rationale: Same mechanism. Twice."))
        #expect(try read(temp, "Notes/Hybrid retrieval.md") == "# Hybrid\nRerankers matter.\n", "nothing changes before accepting")

        try await store.decide(path, .accept, now: now)
        #expect(try read(temp, "Notes/Hybrid retrieval.md") == "# Hybrid\nRerankers matter.\n\n## Related\n- [[Contextual BM25]] — same mechanism\n")
        let decided = try read(temp, path)
        #expect(decided.contains("status: accepted") && decided.contains("decided: 2026-11-09"))
        #expect(try await store.open().isEmpty)
        let log = try read(temp, ProposalStore.logPath)
        #expect(log.contains(" accepted link [[Hybrid retrieval]] (see-also, on-device)") && log.contains("- 2026-11-09 "))
        #expect(try state.acceptance(feature: "see-also", since: now.addingTimeInterval(-60)).rate == 1)
        await #expect(throws: ProposalStoreError.alreadyDecided(path)) { try await store.decide(path, .accept, now: now) }
    }

    @Test func rejectAndDuplicates() async throws {
        let temp = try TempVault()
        let (store, state) = try await store(temp)
        let path = try await store.create(link(), now: now)
        await #expect(throws: ProposalStoreError.self) { try await store.create(link(), now: now) }
        try await store.decide(path, .reject, now: now)
        #expect(try read(temp, "Notes/Hybrid retrieval.md") == "# Hybrid\nRerankers matter.\n")
        #expect(try read(temp, path).contains("status: rejected"))
        await #expect(throws: ProposalStoreError.self, "a rejected change is never proposed again") {
            try await store.create(link(), now: now)
        }
        #expect(try state.acceptance(feature: "see-also", since: now.addingTimeInterval(-60)).rate == 0)
        #expect(try read(temp, ProposalStore.logPath).contains("rejected link"))
    }

    @Test func editKeepsTheEditedDiff() async throws {
        let temp = try TempVault()
        let (store, _) = try await store(temp)
        let path = try await store.create(link(), now: now)
        try await store.decide(path, .edit(ProposalChange(added: ["- [[Contextual BM25]] — my words"])), now: now)
        #expect(try read(temp, "Notes/Hybrid retrieval.md").hasSuffix("## Related\n- [[Contextual BM25]] — my words\n"))
        let file = try read(temp, path)
        #expect(file.contains("status: edited") && file.contains("Edited before accepting"))
        #expect(Proposal.parse(file)?.change.added == ["- [[Contextual BM25]] — my words"])
    }

    @Test func conflictLeavesEverythingOpen() async throws {
        let temp = try TempVault()
        let (store, _) = try await store(temp)
        var edit = link()
        edit.kind = .edit
        edit.change = ProposalChange(removed: ["Rerankers matter."], added: ["Rerankers matter a lot."])
        let path = try await store.create(edit, now: now)
        try temp.put("Notes/Hybrid retrieval.md", "# Hybrid\nI rewrote this.\n")
        await #expect(throws: ProposalError.self) { try await store.decide(path, .accept, now: now) }
        #expect(try read(temp, path).contains("status: open"))
        #expect(!FileManager.default.fileExists(atPath: temp.root.appending(path: ProposalStore.logPath).path(percentEncoded: false)))
    }

    @Test func capAndPause() async throws {
        let temp = try TempVault()
        let (store, state) = try await store(temp)
        for index in 0..<ProposalStore.cap {
            var proposal = link(to: "Other \(index)")
            proposal.feature = "feature-\(index)"
            try await store.create(proposal, now: now)
        }
        #expect(try await store.openCount() == ProposalStore.cap)
        await #expect(throws: ProposalStoreError.queueFull(ProposalStore.cap)) {
            try await store.create(link(to: "One more"), now: now)
        }
        for _ in 0..<19 { try state.record(feature: "tagging", action: .shown, date: now) }
        #expect(try await !store.isPaused(feature: "tagging", now: now), "too few shown to judge")
        try state.record(feature: "tagging", action: .shown, date: now)
        #expect(try await store.isPaused(feature: "tagging", now: now), "20 shown, none accepted")
        try state.record(feature: "tagging", action: .accepted, date: now)
        try state.record(feature: "tagging", action: .edited, date: now)
        #expect(try await !store.isPaused(feature: "tagging", now: now), "2 of 20 is 10%")
        #expect(try await !store.isPaused(feature: "tagging", now: now.addingTimeInterval(ProposalStore.pauseWindow + 1)))
    }

    @Test func claimCreatesANoteAndAIStaysInAI() async throws {
        let temp = try TempVault()
        let (store, _) = try await store(temp)
        let claim = Proposal(kind: .claim, target: "Notes/Rerankers matter.md", feature: "claims", model: "haiku",
                             rationale: "Stated in two notes.", change: ProposalChange(added: ["---", "type: claim", "---", "Rerankers matter."]),
                             created: "")
        let path = try await store.create(claim, now: now)
        #expect(path.hasPrefix("AI/Proposals/"))
        try await store.decide(path, .accept, now: now)
        #expect(try read(temp, "Notes/Rerankers matter.md") == "---\ntype: claim\n---\nRerankers matter.\n")
        await #expect(throws: ProposalStoreError.notFound("Notes/Hybrid retrieval.md")) {
            try await store.decide("Notes/Hybrid retrieval.md", .accept, now: now)
        }
    }
}
