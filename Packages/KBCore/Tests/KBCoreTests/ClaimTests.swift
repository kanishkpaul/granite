import Foundation
import Testing
@testable import KBCore

@Suite struct ClaimTests {
    @Test func renderParsesAsAHeldClaim() throws {
        let text = ClaimNote.render(text: "Hybrid search beats embedding choice.", sources: ["[[Retrieval#^c-abc123]]"],
                                    supersedes: ["[[Old claim]]"], confidence: 1.4, date: "2026-11-09")
        let note = NoteParser.parse(data: Data(text.utf8), path: "Notes/Hybrid search beats embedding choice.md", policy: .builtIn)
        #expect(note.type == .claim && note.status == "held" && note.origin == .human)
        #expect(text.contains("confidence: 1.00\n"))
        let supersedes = note.links.filter { $0.relation == "supersedes" }.map(\.target)
        #expect(supersedes == ["Old claim"])
        let source = try #require(note.links.first { $0.relation == "source" })
        #expect(source.target == "Retrieval")
        #expect(source.blockID == "c-abc123")
    }

    @Test func titles() {
        #expect(ClaimNote.title(for: "Rerankers matter more than embeddings. Also other things.") == "Rerankers matter more than embeddings")
        #expect(ClaimNote.title(for: "Short. Then more") == "Short. Then more")
        let long = String(repeating: "word ", count: 40)
        #expect(ClaimNote.title(for: long).count <= 80 && !ClaimNote.title(for: long).hasSuffix(" "))
    }

    @Test func blockIDsAreAddedOnceToTheRightBlock() throws {
        let text = "---\ntitle: x\n---\n# Heading\nFirst paragraph\ncontinues here.\n\n- a list item\n```\ncode\n```\n"
        let (updated, id) = try #require(ClaimNote.ensureBlockID(in: text, line: 5))
        #expect(updated.contains("continues here. ^\(id)\n") && id.hasPrefix("c-"))
        let again = try #require(ClaimNote.ensureBlockID(in: updated, line: 6))
        #expect(again.text == updated && again.id == id)
        #expect(ClaimNote.ensureBlockID(in: text, line: 8)?.text.contains("- a list item ^") == true)
        #expect(ClaimNote.ensureBlockID(in: text, line: 4) == nil, "headings")
        #expect(ClaimNote.ensureBlockID(in: text, line: 10) == nil, "code")
        #expect(ClaimNote.ensureBlockID(in: text, line: 2) == nil, "frontmatter")
    }
}
