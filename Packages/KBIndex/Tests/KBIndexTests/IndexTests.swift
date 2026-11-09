import Foundation
import GRDB
import KBCore
import KBTestSupport
import Testing
@testable import KBIndex

final class TempVault: @unchecked Sendable {
    let root: URL
    let vault: Vault
    let dbURL: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-index-\(UUID().uuidString)")
        root = base.appending(path: "vault")
        dbURL = base.appending(path: "support/index.sqlite")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        vault = Vault(root: root)
    }

    func put(_ path: String, _ text: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func remove(_ path: String) throws { try FileManager.default.removeItem(at: root.appending(path: path)) }

    func bumpMtime(_ path: String, by seconds: Double = 5) throws {
        let url = root.appending(path: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        let date = (attributes[.modificationDate] as? Date ?? Date()).addingTimeInterval(seconds)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
    }

    func indexer() throws -> (IndexDatabase, Indexer) {
        let database = try IndexDatabase(url: dbURL)
        return (database, Indexer(database: database, vault: vault, policy: .builtIn, batchSize: 3))
    }
}

func rowid(_ database: IndexDatabase, _ path: String) throws -> Int64? {
    try database.pool.read { db in try Int64.fetchOne(db, sql: "SELECT rowid FROM objects WHERE path = ?", arguments: [path]) }
}

@Suite struct IndexTests {
    func seeded() throws -> TempVault {
        let temp = try TempVault()
        try temp.put("Notes/Hybrid retrieval.md", """
            ---
            type: claim
            status: held
            supersedes: ["[[Embedding choice]]"]
            source: ["[[anthropic2024contextual#^z-1]]"]
            aliases: [Hybrid search]
            ---
            Hybrid search plus reranking beats embedding choice. ^c1
            See [[#^c1]] and [[Folder/Deep note]] and [[nowhere]].
            """)
        try temp.put("Notes/Embedding choice.md", "---\nstatus: superseded\n---\nEmbedding model choice drives quality.\n")
        try temp.put("Papers/anthropic2024contextual.md", """
            ---
            type: source
            ---
            ## Annotations
            > Prepending context to chunks cut retrieval failures by 35%. ^z-1
            """)
        try temp.put("Archive/Folder/Deep note.md", "Deep content about [[Hybrid search]].\n")
        try temp.put("AI/Synthesis/retrieval.md", "Synthesis says hybrid reranking wins. [[Hybrid retrieval]]\n")
        try temp.put("Private/diary.md", "Private hybrid thoughts.\n")
        try temp.put("Daily/2026-11-09.md", "Read about reranking in [[Hybrid retrieval]].\n")
        return temp
    }

    @Test func indexesAndResolvesLinks() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        let report = try await indexer.reconcile()
        #expect(report.parsed == 7)

        let stats = try database.stats()
        #expect(stats.objects == 7)
        #expect(stats.unresolvedLinks == 1)
        #expect(try database.unresolvedLinks().map(\.target) == ["nowhere"])

        let back = try database.backlinks(to: "Notes/Hybrid retrieval.md")
        #expect(Set(back.map(\.path)) == ["AI/Synthesis/retrieval.md", "Daily/2026-11-09.md", "Archive/Folder/Deep note.md"])

        let typed = try database.backlinks(to: "Notes/Embedding choice.md")
        #expect(typed.map(\.relation) == ["supersedes"])
        let cites = try database.backlinks(to: "Papers/anthropic2024contextual.md")
        #expect(cites.map(\.relation) == ["source"])
        #expect(try database.backlinks(to: "Archive/Folder/Deep note.md").count == 1)
        #expect(try database.resolvedTargets(from: "Notes/Hybrid retrieval.md")
            == ["anthropic2024contextual", "embedding choice", "folder/deep note"])
        let from = "Notes/Hybrid retrieval.md"
        #expect(try database.resolve(linkTarget: "Embedding choice", from: from) == "Notes/Embedding choice.md")
        #expect(try database.resolve(linkTarget: "folder/Deep note", from: from) == "Archive/Folder/Deep note.md")
        #expect(try database.resolve(linkTarget: "Hybrid search", from: from) == from)
        #expect(try database.resolve(linkTarget: "", from: from) == from)
        #expect(try database.resolve(linkTarget: "nowhere", from: from) == nil)
    }

    @Test func searchRespectsEvidenceScopeAndLabels() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()

        let defaultHits = try database.search("hybrid")
        #expect(!defaultHits.contains { $0.path.hasPrefix("AI/") })
        #expect(defaultHits.contains { $0.path == "Notes/Hybrid retrieval.md" })

        let withAI = try database.search("hybrid", options: SearchOptions(includeAI: true))
        #expect(withAI.contains { $0.path.hasPrefix("AI/") })

        let cloudOnly = try database.search("hybrid", options: SearchOptions(maxLabel: .cloud))
        #expect(!cloudOnly.contains { $0.path.hasPrefix("Private/") || $0.path.hasPrefix("Daily/") })

        let prefix = try database.search("rerank")
        #expect(prefix.contains { $0.path == "Notes/Hybrid retrieval.md" })

        let folder = try database.search("hybrid", options: SearchOptions(folders: ["Private"]))
        #expect(folder.map(\.path) == ["Private/diary.md"])

        let block = try #require(try database.search("prepending context").first)
        #expect(block.blockID == "z-1")
        #expect(block.headingPath == "Annotations")
        #expect(block.snippet.contains("[Prepending]"))

        #expect(throws: QueryError.self) { try database.search("  ** ") }
        // FTS5 operators in user input are quoted as plain words, not executed.
        #expect(try database.search("NEAR OR AND hybrid").isEmpty)
        #expect(try database.search("hybrid\" OR \"x").isEmpty)
    }

    @Test func titleSearchIncludesAliases() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        #expect(try database.titles(matching: "embed").first?.title == "Embedding choice")
        #expect(try database.titles(matching: "hybrid search").map(\.title) == ["Hybrid retrieval"])
        #expect(try database.titles(matching: "100%").isEmpty)
    }

    @Test func incrementalReconcile() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let target = try rowid(database, "Notes/Hybrid retrieval.md")

        let quiet = try await indexer.reconcile()
        #expect(quiet.parsed == 0 && quiet.unchanged == 7)

        // Same bytes, new mtime: hash check avoids a re-parse.
        try temp.bumpMtime("Notes/Embedding choice.md")
        let touched = try await indexer.reconcile()
        #expect(touched.touched == 1 && touched.parsed == 0)

        // An edit re-parses in place: the rowid, and so other notes' resolved links, survive.
        try temp.put("Notes/Hybrid retrieval.md", "Rewritten body about quantum gardening.\n")
        try temp.bumpMtime("Notes/Hybrid retrieval.md")
        let edited = try await indexer.reconcile()
        #expect(edited.parsed == 1)
        #expect(try rowid(database, "Notes/Hybrid retrieval.md") == target)
        #expect(try database.search("quantum gardening").first?.path == "Notes/Hybrid retrieval.md")
        #expect(try database.search("reranking beats").isEmpty)
        #expect(try database.backlinks(to: "Notes/Hybrid retrieval.md").count == 2)

        // Delete: rows and FTS entries go; links into it become unresolved.
        try temp.remove("Notes/Embedding choice.md")
        let removed = try await indexer.reconcile()
        #expect(removed.removed == 1)
        #expect(try database.search("embedding model").isEmpty)
    }

    @Test func renameReresolvesLinksByName() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        let text = try String(contentsOf: temp.root.appending(path: "Notes/Hybrid retrieval.md"), encoding: .utf8)
        try temp.remove("Notes/Hybrid retrieval.md")
        try temp.put("Archive/Hybrid retrieval.md", text)
        let report = try await indexer.reconcile()
        #expect(report.removed == 1 && report.parsed == 1)
        #expect(try database.backlinks(to: "Archive/Hybrid retrieval.md").count == 3)
        #expect(try database.stats().unresolvedLinks == 1)
    }

    @Test func updateHandlesWatcherPaths() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        try temp.put("Inbox/2026-11-09 1200.md", "Captured idea about [[nowhere]] and [[Hybrid retrieval]].\n")
        try temp.remove("Private/diary.md")
        let report = try await indexer.update(paths: ["Inbox/2026-11-09 1200.md", "Private/diary.md"])
        #expect(report.parsed == 1 && report.removed == 1)
        #expect(try database.stats().objects == 7)
        #expect(try database.unresolvedLinks().first?.count == 2)
    }

    @Test func readOnlyOpenAndLookups() async throws {
        let temp = try seeded()
        #expect(throws: IndexDatabase.OpenError.self) { try IndexDatabase(readOnlyAt: temp.dbURL) }
        let (writable, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        try temp.bumpMtime("Daily/2026-11-09.md", by: 60)
        _ = try await indexer.reconcile()

        let reader = try IndexDatabase(readOnlyAt: temp.dbURL)
        let note = try #require(try reader.note(path: "Private/diary.md"))
        #expect(note.aiLabel == "local" && note.type == "note")
        #expect(try reader.note(path: "nope.md") == nil)
        #expect(try reader.recent(limit: 1).first?.path == "Daily/2026-11-09.md")
        #expect(try reader.recent(limit: 50, since: Date.distantFuture).isEmpty)
        #expect(try reader.search("hybrid").isEmpty == false)
        #expect(throws: (any Error).self) {
            try reader.pool.write { db in try db.execute(sql: "DELETE FROM objects") }
        }
        try await writable.pool.write { db in
            try db.execute(sql: "UPDATE objects SET id = 'X1' WHERE path = 'Notes/Embedding choice.md'")
        }
        #expect(try reader.note(id: "X1")?.path == "Notes/Embedding choice.md")
    }

    @Test func scopedResolutionAfterIncrementalUpdates() async throws {
        let temp = try seeded()
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        #expect(try database.unresolvedLinks().map(\.target) == ["nowhere"])

        // A new note resolves a link in an unchanged note.
        try temp.put("Inbox/nowhere.md", "now it exists\n")
        _ = try await indexer.update(paths: ["Inbox/nowhere.md"])
        #expect(try database.stats().unresolvedLinks == 0)
        #expect(try database.backlinks(to: "Inbox/nowhere.md").map(\.path) == ["Notes/Hybrid retrieval.md"])

        // Deleting the shorter-path match falls back to the remaining note with that name.
        try temp.put("Archive/Deep/nowhere.md", "a second one\n")
        _ = try await indexer.update(paths: ["Archive/Deep/nowhere.md"])
        try temp.remove("Inbox/nowhere.md")
        _ = try await indexer.update(paths: ["Inbox/nowhere.md"])
        #expect(try database.backlinks(to: "Archive/Deep/nowhere.md").map(\.path) == ["Notes/Hybrid retrieval.md"])

        // A path-suffix link ("folder/name") resolves when its note appears.
        try temp.put("Notes/Suffix.md", "see [[Deep/Target]]\n")
        _ = try await indexer.update(paths: ["Notes/Suffix.md"])
        #expect(try database.stats().unresolvedLinks == 1)
        try temp.put("Archive/Deep/Target.md", "target\n")
        _ = try await indexer.update(paths: ["Archive/Deep/Target.md"])
        #expect(try database.stats().unresolvedLinks == 0)

        // Touch-only updates skip resolution entirely and change nothing.
        try temp.bumpMtime("Notes/Suffix.md")
        let touched = try await indexer.update(paths: ["Notes/Suffix.md"])
        #expect(touched.touched == 1 && touched.parsed == 0)
        #expect(try database.backlinks(to: "Archive/Deep/Target.md").count == 1)
    }

    @Test func schemaVersionMismatchRebuilds() async throws {
        let temp = try seeded()
        do {
            let (database, indexer) = try temp.indexer()
            #expect(database.isFresh)
            _ = try await indexer.reconcile()
            try await database.pool.write { db in try db.execute(sql: "PRAGMA user_version = 999") }
            try database.pool.close()
        }
        let reopened = try IndexDatabase(url: temp.dbURL)
        #expect(reopened.isFresh)
        #expect(try reopened.stats().objects == 0)
    }

    @Test func fixtureVaultRecall() async throws {
        let temp = try TempVault()
        let summary = try FixtureGenerator(noteCount: 1_000, seed: 3, queryCount: 50).write(to: temp.root)
        let database = try IndexDatabase(url: temp.dbURL)
        let indexer = Indexer(database: database, vault: temp.vault, policy: .builtIn)
        let report = try await indexer.reconcile()
        #expect(report.parsed == 1_000)
        let stats = try database.stats()
        #expect(stats.yamlErrors == 0)
        #expect(stats.unresolvedLinks > 0 && stats.unresolvedLinks < stats.links / 4)

        var found = 0
        for query in summary.queries {
            let hits = try database.search(query.query, options: SearchOptions(limit: 10, includeAI: true))
            if hits.contains(where: { $0.path == query.expected }) { found += 1 }
        }
        let recall = Double(found) / Double(summary.queries.count)
        #expect(recall >= 0.9, "BM25 recall@10 on synthetic queries was \(recall)")
    }
}
