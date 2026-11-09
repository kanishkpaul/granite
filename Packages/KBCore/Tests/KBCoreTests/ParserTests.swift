import Foundation
import Testing
@testable import KBCore

func golden(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Golden"))
    return try Data(contentsOf: url)
}

func parse(_ name: String, path: String? = nil, policy: VaultPolicy = .builtIn) throws -> ParsedNote {
    NoteParser.parse(data: try golden(name), path: path ?? "Notes/\(name).md", policy: policy)
}

func targets(_ note: ParsedNote) -> [String] { note.links.map(\.target) }

@Suite struct FrontmatterTests {
    @Test func claimProperties() throws {
        let note = try parse("claim")
        #expect(note.id == "01JC9Q7Z5W3K8M2R4T6V8X0Y1A")
        #expect(note.type == .claim)
        #expect(note.origin == .human)
        #expect(note.status == "held")
        #expect(note.created == "2026-11-08")
        #expect(note.frontmatter?["confidence"] == .number(0.7))
        #expect(note.frontmatter?["created"] == .date("2026-11-08"))
        #expect(note.tags == ["retrieval", "search/hybrid"])
        let supersedes = note.links.filter { $0.relation == "supersedes" }
        #expect(supersedes.map(\.target) == ["Embedding model choice drives retrieval quality"])
        let source = try #require(note.links.first { $0.relation == "source" })
        #expect(source.target == "anthropic2024contextual")
        #expect(source.blockID == "z-7HQ2KX9P")
        #expect(note.blocks.last?.blockID == "claim-1")
        #expect(note.blocks.last?.text.hasSuffix("you pick.") == true)
        #expect(note.blocks.last?.startLine == 14)
    }

    @Test func crlfFrontmatterAndBody() throws {
        let note = try parse("crlf")
        #expect(note.frontmatter?["title"] == .string("Windows note"))
        #expect(note.tags == ["crlf", "inline-tag"])
        #expect(targets(note) == ["Other note"])
        #expect(note.blocks.first?.kind == .heading)
        #expect(note.blocks.first?.startLine == 6)
        #expect(note.blocks.allSatisfy { !$0.text.contains("\r") })
    }

    @Test func byteOrderMarkIsIgnored() throws {
        let note = try parse("bom")
        #expect(note.id == "bom")
        #expect(note.blocks.map(\.text) == ["Body with BOM."])
    }

    @Test func missingAndUnclosedFrontmatter() throws {
        let plain = try parse("no-frontmatter")
        #expect(plain.frontmatter == nil)
        #expect(plain.links.map(\.target) == ["Target", "Diagram.png"])
        #expect(plain.links[0].alias == "an alias")
        #expect(plain.links[1].isEmbed && plain.links[1].relation == "embed")

        let unclosed = try parse("unclosed-frontmatter")
        #expect(unclosed.frontmatter == nil)
        #expect(targets(unclosed) == ["Link"])
    }

    @Test func badYAMLStillIndexesBody() throws {
        let note = try parse("bad-yaml")
        #expect(note.frontmatter?.error != nil)
        #expect(note.frontmatter?.properties.isEmpty == true)
        #expect(note.tags == ["still-tagged"])
    }
}

@Suite struct BodyTests {
    @Test func codeAndMathAreNotScannedForLinks() throws {
        let note = try parse("code-blocks")
        #expect(targets(note) == ["Outside", "After code"])
        #expect(note.tags.isEmpty)
        let kinds = note.blocks.map(\.kind)
        #expect(kinds == [.paragraph, .code, .code, .paragraph, .math])
        #expect(note.blocks[1].text.contains("[[Not a link]]"))
        #expect(note.blocks[1].startLine == 3 && note.blocks[1].endLine == 5)
    }

    @Test func callouts() throws {
        let note = try parse("callouts")
        let callouts = note.blocks.filter { $0.kind == .callout }
        #expect(callouts.map(\.calloutType) == ["prompt", "note"])
        #expect(callouts[0].blockID == "prompt-1")
        #expect(callouts[0].headingPath == "Prompts")
        #expect(note.blocks.contains { $0.kind == .quote && $0.text.contains("two lines") })
        #expect(targets(note) == ["Linked from callout"])
    }

    @Test func blockIDs() throws {
        let note = try parse("block-ids")
        let ids = note.blocks.compactMap(\.blockID)
        #expect(ids == ["para-1", "li-1", "list-tail", "table-1"])
        let item = try #require(note.blocks.first { $0.text.hasPrefix("- item two") })
        #expect(item.text.contains("continued line"))
        #expect(note.blocks.first { $0.blockID == "para-1" }?.text == "First paragraph.")
        #expect(note.links.first?.target == "Table link")
        #expect(note.links.first?.alias == "alias")
        #expect(note.blocks.last?.blockID == nil)
    }

    @Test func tags() throws {
        let note = try parse("tags")
        #expect(note.tags == ["alpha", "beta", "y2026", "nested/deep/tag", "日本語", "émigré", "slash"])
    }

    @Test func linkForms() throws {
        let note = try parse("links", path: "Notes/Sub/links.md")
        let self1 = note.links[0]
        #expect(self1.target == "" && self1.heading == "Section")
        #expect(note.links[1].blockID == "abc")
        #expect(note.links[2].target == "Note" && note.links[2].heading == "B")
        let markdown = note.links[3]
        #expect(markdown.syntax == .markdown)
        #expect(markdown.target == "Notes/Other Note.md")
        #expect(markdown.heading == "Part")
        #expect(note.links[4].target == "Notes/Sub/With Spaces.md")
        #expect(note.links.count == 5)
    }

    @Test func commentsAreSkippedButManagedRegionsIndex() throws {
        let note = try parse("comments")
        #expect(targets(note) == ["Kept"])
        #expect(!note.tags.contains("hidden"))
        #expect(note.blocks.contains { $0.blockID == "z-7HQ2KX9P" && $0.headingPath == "Annotations" })
    }

    @Test func headingPathsNest() {
        let text = "# A\n## B\n### C\ntext\n## D\nmore\n"
        let scan = BlockParser.scan(Lines.split(text))
        let paragraphs = scan.blocks.filter { $0.kind == .paragraph }
        #expect(paragraphs.map(\.headingPath) == ["A > B > C", "A > D"])
    }
}

@Suite struct PolicyTests {
    @Test func builtInLabels() {
        let policy = VaultPolicy.builtIn
        #expect(policy.policy(for: "Private/diary.md").ai == .local)
        #expect(policy.policy(for: "Private/diary.md").mcpHidden)
        #expect(policy.policy(for: "AI/Digests/x.md").evidence == false)
        #expect(policy.policy(for: "notes/lowercase.md").ai == .cloud)
        #expect(policy.policy(for: "Unknown/x.md").ai == .local)
        #expect(policy.policy(for: "root.md").agents == .propose)
    }

    @Test func noteLabelCanTightenButNotLoosen() {
        let tighter = NoteParser.parse(data: Data("---\nai: local\n---\nx".utf8), path: "Notes/a.md", policy: .builtIn)
        #expect(tighter.aiLabel == .local)
        let looser = NoteParser.parse(data: Data("---\nai: cloud\n---\nx".utf8), path: "Private/a.md", policy: .builtIn)
        #expect(looser.aiLabel == .local)
    }

    @Test func aiFolderCannotClaimHumanOrigin() {
        let note = NoteParser.parse(data: Data("---\norigin: human\n---\nx".utf8), path: "AI/Synthesis/a.md",
                                    policy: .builtIn)
        #expect(note.origin == .ai)
        #expect(note.type == .synthesis)
    }

    @Test func parsesPolicyYAML() throws {
        let yaml = """
        folders:
          Notes/:     { ai: cloud, origin: human,  agents: propose }
          Private/:   { ai: local, origin: human,  agents: none, mcp: hidden }
          AI/:        { ai: cloud, origin: ai,     agents: write, evidence: false }
          Clippings/: { ai: cloud, origin: source, agents: none, trust: untrusted }
        default: { ai: none }
        budget: { monthly_usd: 20, alert_usd: 15, hard_stop_usd: 25 }
        repos: [ "~/code/granite" ]
        """
        let policy = try VaultPolicy.parse(yaml: yaml)
        #expect(policy.policy(for: "Private/x.md").mcpHidden)
        #expect(policy.policy(for: "Clippings/x.md").trust == "untrusted")
        #expect(policy.policy(for: "AI/x.md").evidence == false)
        #expect(policy.fallback.ai == AILabel.none)
        #expect(policy.budget?.hardStopUSD == 25)
        #expect(policy.repos == ["~/code/granite"])
    }

    @Test func rejectsInvalidLabels() {
        #expect(throws: PolicyError.self) {
            try VaultPolicy.parse(yaml: "folders:\n  Notes/: { ai: public, origin: human, agents: none }")
        }
    }

    @Test func strictestLabelWins() {
        #expect(AILabel.strictest([.cloud, .pcc, .cloud]) == .pcc)
        #expect(AILabel.strictest([.cloud, .none, .local]) == AILabel.none)
    }
}
