import Foundation
import Testing
@testable import KBCore

@Suite struct ProposalTests {
    let link = Proposal(kind: .link, target: "[[Hybrid retrieval]]", feature: "see-also", model: "on-device",
                        rationale: "Both argue rerankers matter.", change: ProposalChange(added: ["- [[Contextual BM25]] — same mechanism"]),
                        citations: ["[[contextual#^z-1]]"], created: "2026-11-09", label: .cloud)

    @Test func rendersAndParsesBack() throws {
        let text = link.render()
        #expect(text.contains("type: proposal") && text.contains("origin: ai") && text.contains("ai: cloud"))
        let note = NoteParser.parse(data: Data(text.utf8), path: "AI/Proposals/x.md", policy: .builtIn)
        #expect(note.type == .proposal && note.origin == .ai)
        let parsed = try #require(Proposal.parse(text, path: "AI/Proposals/x.md"))
        #expect(parsed.kind == .link && parsed.target == "[[Hybrid retrieval]]" && parsed.status == .open)
        #expect(parsed.change == link.change && parsed.rationale == "Both argue rerankers matter.")
        #expect(parsed.citations == ["[[contextual#^z-1]]"] && parsed.label == .cloud)
        #expect(Proposal.parse("---\ntype: note\n---\nx") == nil)
    }

    @Test func fileNames() {
        #expect(Proposal.fileName(kind: .link, target: "[[Notes/Hybrid: retrieval|alias]]", stamp: "2026-11-09 1432")
                == "AI/Proposals/2026-11-09 1432 link Hybrid  retrieval.md")
    }

    @Test func linkGoesUnderRelated() throws {
        guard case .modify(let first) = try ProposalApplier.apply(link, to: "# Hybrid\nBody text.\n\n") else { Issue.record("modify"); return }
        #expect(first == "# Hybrid\nBody text.\n\n## Related\n- [[Contextual BM25]] — same mechanism\n")
        guard case .modify(let second) = try ProposalApplier.apply(link, to: "Body\n## Related\n- [[A]]\n\n## Later\nx\n") else { return }
        #expect(second == "Body\n## Related\n- [[A]]\n- [[Contextual BM25]] — same mechanism\n\n## Later\nx\n")
    }

    @Test func editReplacesExactLinesOrConflicts() throws {
        var edit = link
        edit.kind = .edit
        edit.change = ProposalChange(removed: ["Old sentence."], added: ["New sentence.", "Another."])
        guard case .modify(let text) = try ProposalApplier.apply(edit, to: "Intro\nOld sentence.  \nOutro\n") else { return }
        #expect(text == "Intro\nNew sentence.\nAnother.\nOutro\n")
        #expect(throws: ProposalError.self) { try ProposalApplier.apply(edit, to: "Intro\nChanged by you.\n") }
        #expect(throws: ProposalError.self) { try ProposalApplier.apply(edit, to: nil) }
    }

    @Test func promptAndRuleAppend() throws {
        var prompt = link
        prompt.kind = .prompt
        prompt.change = ProposalChange(added: ["> [!prompt] What beats embedding choice?", "> Hybrid + rerank. ^p-1"])
        guard case .modify(let text) = try ProposalApplier.apply(prompt, to: "Body") else { return }
        #expect(text == "Body\n\n> [!prompt] What beats embedding choice?\n> Hybrid + rerank. ^p-1\n")
    }

    @Test func claimCreatesANote() throws {
        var claim = link
        claim.kind = .claim
        claim.target = "Notes/Rerankers matter.md"
        claim.change = ProposalChange(added: ["---", "type: claim", "---", "Rerankers matter."])
        #expect(try ProposalApplier.apply(claim, to: nil) == .create(path: "Notes/Rerankers matter.md",
                                                                       text: "---\ntype: claim\n---\nRerankers matter.\n"))
        #expect(throws: ProposalError.self) { try ProposalApplier.apply(claim, to: "exists") }
    }

    @Test func tagsGoIntoFrontmatter() throws {
        var tag = link
        tag.kind = .tag
        tag.change = ProposalChange(added: ["#retrieval", "search"])
        guard case .modify(let flow) = try ProposalApplier.apply(tag, to: "---\ntags: [search]\nid: x\n---\nb\n") else { return }
        #expect(flow == "---\ntags: [search, retrieval]\nid: x\n---\nb\n")
        guard case .modify(let block) = try ProposalApplier.apply(tag, to: "---\ntags:\n  - a\nid: x\n---\nb\n") else { return }
        #expect(block == "---\ntags:\n  - a\n  - retrieval\n  - search\nid: x\n---\nb\n")
        guard case .modify(let missing) = try ProposalApplier.apply(tag, to: "---\nid: x\n---\nb\n") else { return }
        #expect(missing == "---\ntags: [retrieval, search]\nid: x\n---\nb\n")
        guard case .modify(let none) = try ProposalApplier.apply(tag, to: "body only\n") else { return }
        #expect(none == "---\ntags: [retrieval, search]\n---\nbody only\n")
    }
}
