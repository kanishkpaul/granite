import Foundation
import GRDB
import KBCore
import Testing
@testable import KBIndex

@Suite struct RenameTests {
    func service(_ temp: TempVault) async throws -> (IndexDatabase, RenameService) {
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        return (database, RenameService(indexer: indexer, writer: SafeWriter(vault: temp.vault)))
    }

    func read(_ temp: TempVault, _ path: String) throws -> String {
        try String(contentsOf: temp.root.appending(path: path), encoding: .utf8)
    }

    @Test func rewritesEveryLinkForm() async throws {
        let temp = try TempVault()
        try temp.put("Inbox/2026-11-01 0900.md", "A capture about hybrid search. ^cap\n## Part\nmore\n")
        try temp.put("Notes/Linker.md", """
            ---
            supports: ["[[2026-11-01 0900]]"]
            ---
            See [[2026-11-01 0900]], [[2026-11-01 0900#Part]], [[2026-11-01 0900#^cap|the capture]] and ![[2026-11-01 0900]].
            Case: [[2026-11-01 0900.md]].
            ```
            [[2026-11-01 0900]] in code stays
            ```
            The name 2026-11-01 0900 in prose stays.
            """)
        try temp.put("Notes/Deep/Md.md", "A [markdown link](../../Inbox/2026-11-01%200900.md#Part) here.\n")
        let (database, renamer) = try await service(temp)

        let report = try await renamer.rename(from: "Inbox/2026-11-01 0900.md", to: "Notes/Hybrid search.md")
        #expect(report.rewrittenFiles == ["Notes/Deep/Md.md", "Notes/Linker.md"])
        #expect(report.rewrittenLinks == 7)

        let linker = try read(temp, "Notes/Linker.md")
        #expect(linker.contains(#"supports: ["[[Hybrid search]]"]"#))
        #expect(linker.contains("See [[Hybrid search]], [[Hybrid search#Part]], [[Hybrid search#^cap|the capture]] and ![[Hybrid search]]."))
        #expect(linker.contains("Case: [[Hybrid search.md]]."))
        #expect(linker.contains("[[2026-11-01 0900]] in code stays"))
        #expect(linker.contains("The name 2026-11-01 0900 in prose stays."))
        #expect(try read(temp, "Notes/Deep/Md.md") == "A [markdown link](../Hybrid%20search.md#Part) here.\n")

        #expect(try database.backlinks(to: "Notes/Hybrid search.md").count == 7)
        #expect(try database.unresolvedLinks().isEmpty)
        #expect(try database.note(path: "Inbox/2026-11-01 0900.md") == nil)
    }

    @Test func pathStyleLinksAndAmbiguousNames() async throws {
        let temp = try TempVault()
        try temp.put("Notes/Topic.md", "topic\n")
        try temp.put("Archive/Old.md", "old\n")
        try temp.put("Notes/A.md", "[[Archive/Old]] and [[Old]]\n")
        let (_, renamer) = try await service(temp)
        _ = try await renamer.rename(from: "Archive/Old.md", to: "Projects/Topic.md")
        // "Topic" already exists, so links switch to the full path to stay unambiguous.
        #expect(try read(temp, "Notes/A.md") == "[[Projects/Topic]] and [[Projects/Topic]]\n")
    }

    @Test func moveKeepsBareLinksAndRewritesSelfLinks() async throws {
        let temp = try TempVault()
        try temp.put("Notes/Self.md", "Jump to [[Self#End]].\n## End\n")
        try temp.put("Notes/Other.md", "[[Self]]\n")
        let (database, renamer) = try await service(temp)
        let report = try await renamer.rename(from: "Notes/Self.md", to: "Archive/Self.md")
        #expect(try read(temp, "Archive/Self.md") == "Jump to [[Self#End]].\n## End\n")
        #expect(try read(temp, "Notes/Other.md") == "[[Self]]\n")
        // Bare names still resolve after a move, so nothing needs rewriting.
        #expect(report.rewrittenLinks == 0 && report.rewrittenFiles.isEmpty)
        #expect(try database.backlinks(to: "Archive/Self.md").map(\.path) == ["Notes/Other.md"])
    }

    @Test func refusesBadRenames() async throws {
        let temp = try TempVault()
        try temp.put("Notes/A.md", "a\n")
        try temp.put("Notes/B.md", "b\n")
        let (_, renamer) = try await service(temp)
        await #expect(throws: RenameError.notMarkdown("Notes/A.txt")) { try await renamer.rename(from: "Notes/A.md", to: "Notes/A.txt") }
        await #expect(throws: RenameError.notIndexed("Notes/Z.md")) { try await renamer.rename(from: "Notes/Z.md", to: "Notes/Y.md") }
        await #expect(throws: SafeWriteError.destinationExists("Notes/B.md")) { try await renamer.rename(from: "Notes/A.md", to: "Notes/B.md") }
    }

    @Test func relativePaths() {
        #expect(RenameService.relativePath(to: "Notes/X.md", from: ["Notes", "Deep"]) == "../X.md")
        #expect(RenameService.relativePath(to: "Notes/Deep/X.md", from: ["Notes"]) == "Deep/X.md")
        #expect(RenameService.relativePath(to: "X.md", from: []) == "X.md")
        #expect(RenameService.relativePath(to: "A/X.md", from: ["B", "C"]) == "../../A/X.md")
    }
}
