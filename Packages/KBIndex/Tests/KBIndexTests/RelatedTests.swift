import Foundation
import KBCore
import Testing
@testable import KBIndex

@Suite struct RelatedTests {
    func setUp(_ temp: TempVault) async throws -> (IndexDatabase, RelatedFinder) {
        try temp.put("Notes/Hybrid retrieval.md", "# Hybrid\nCombine keywords and vectors. Already links [[Linked note]].\n")
        try temp.put("Notes/Linked note.md", "Hybrid retrieval is linked already.\n")
        try temp.put("Notes/Reciprocal rank fusion.md", "---\naliases: [RRF]\n---\nFuse ranked lists.\n")
        try temp.put("Notes/Garage.md", "my car needs new brakes and tyres\n")
        try temp.put("Notes/Retrieval.md", "one word title\n")
        try temp.put("AI/Synthesis/Car summary.md", "car brakes tyres summary\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        _ = try await EmbeddingJob(database: database, embedder: FakeEmbedder()).run()
        return (database, RelatedFinder(database: database, vectors: VectorIndex(database: database), embedder: FakeEmbedder(),
                                        minSimilarity: 0.3))
    }

    @Test func mentionsAreUnlinkedTitlesAndAliases() async throws {
        let temp = try TempVault()
        let (_, finder) = try await setUp(temp)
        let text = """
            We use reciprocal rank fusion here, aka RRF, and the [[Garage]] link. retrieval in lowercase.
            `Hybrid retrieval` in code. Notes on Linked note too.
            """
        let found = try await finder.forText(text, in: "Notes/Hybrid retrieval.md", limit: 5)
        #expect(found.filter { $0.reason == .mention }.map(\.path) == ["Notes/Reciprocal rank fusion.md"])
        #expect(found.first?.reason == .mention && found.first?.snippet == "reciprocal rank fusion")
        // One-word titles need a capitalized mention mid-sentence.
        let capital = try await finder.forText("Some notes on Retrieval today", in: "Notes/Garage.md")
        #expect(capital.map(\.path).contains("Notes/Retrieval.md"))
        let start = try await finder.forText("Retrieval is a word", in: "Notes/Garage.md")
        #expect(!start.contains { $0.path == "Notes/Retrieval.md" && $0.reason == .mention })
    }

    @Test func similarPassagesSkipAIAndLinkedNotes() async throws {
        let temp = try TempVault()
        let (_, finder) = try await setUp(temp)
        let found = try await finder.forText("the automobile brakes and tyres are worn", in: "Notes/Hybrid retrieval.md")
        #expect(found.first?.path == "Notes/Garage.md" && found.first?.reason == .similar)
        #expect(!found.contains { $0.path.hasPrefix("AI/") })
        let forNote = try await finder.forNote("Notes/Hybrid retrieval.md", limit: 10)
        #expect(!forNote.contains { $0.path == "Notes/Linked note.md" || $0.path == "Notes/Hybrid retrieval.md" })
    }

    @Test func seeAlsoProposesOncePerNoteAndRespectsRejections() async throws {
        let temp = try TempVault()
        try temp.put("Notes/Brakes.md", "Check the car brakes and tyres before the trip.\n")
        let (_, finder) = try await setUp(temp)
        let (database, indexer) = (finder.database, Indexer(database: finder.database, vault: temp.vault, policy: .builtIn))
        _ = database
        let store = ProposalStore(indexer: indexer, writer: SafeWriter(vault: temp.vault), state: nil)
        let job = SeeAlsoJob(finder: finder, store: store) { _, candidate in ("Both are about \(candidate.title).", "fake") }

        let first = try await job.run(paths: ["Notes/Brakes.md", "AI/Synthesis/Car summary.md"])
        #expect(first.count == 1)
        let proposal = try #require(try await store.open().first)
        #expect(proposal.target == "[[Notes/Brakes]]" && proposal.change.added == ["- [[Garage]] — related"])
        #expect(proposal.rationale == "Both are about Garage." && proposal.model == "fake")

        try await store.decide(try #require(proposal.path), .reject)
        let second = try await job.run(paths: ["Notes/Brakes.md"])
        let next = try await store.open()
        #expect(second.count <= 1 && !next.contains { $0.change.added == ["- [[Garage]] — related"] })
    }
}
