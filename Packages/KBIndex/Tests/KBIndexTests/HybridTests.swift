import Foundation
import GRDB
import KBCore
import Testing
@testable import KBIndex

/// Bag-of-words hashing with a synonym table, so "automobile" lands near "car" without sharing a word.
struct FakeEmbedder: Embedder {
    let modelID: String
    let dimension = 64
    static let synonyms = ["automobile": "car", "vehicle": "car", "canine": "dog", "puppy": "dog"]

    init(modelID: String = "fake-1") { self.modelID = modelID }

    func vector(_ text: String) -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        for raw in text.lowercased().split(whereSeparator: { !$0.isLetter }) {
            let word = Self.synonyms[String(raw)] ?? String(raw)
            var hash: UInt64 = 1469598103934665603
            for byte in word.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            vector[Int(hash % UInt64(dimension))] += 1
        }
        return vector
    }

    func embed(documents: [String]) async throws -> [[Float]] { documents.map(vector) }
    func embed(query: String) async throws -> [Float] { vector(query) }
}

/// Scores by how many query words appear in the document; documents containing "irrelevant" score 0.
struct FakeReranker: Reranker {
    let modelID = "fake-rerank"
    func scores(query: String, documents: [String]) async throws -> [Double] {
        let words = Set(query.lowercased().split(separator: " ").map(String.init))
        return documents.map { doc in
            let lower = doc.lowercased()
            if lower.contains("irrelevant") { return 0 }
            return Double(words.filter { lower.contains($0) }.count) / Double(max(1, words.count))
        }
    }
}

@Suite struct HybridTests {
    func seeded() async throws -> (TempVault, IndexDatabase, Indexer) {
        let temp = try TempVault()
        try temp.put("Notes/Cars.md", "# Garage\nMy car needs new brakes before winter.\n")
        try temp.put("Notes/Dogs.md", "# Pets\nThe dog sleeps all afternoon.\n")
        try temp.put("Notes/Both.md", "brakes and dog food on the shopping list\n")
        try temp.put("Notes/Noise.md", "irrelevant brakes brakes brakes\n")
        try temp.put("Private/diary.md", "my car is a secret\n")
        try temp.put("Notes/Unembedded.md", "---\nai: none\n---\ncar facts that must never be embedded\n")
        try temp.put("AI/Synthesis/cars.md", "A model wrote about the car.\n")
        let (database, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        return (temp, database, indexer)
    }

    func searcher(_ database: IndexDatabase, reranker: (any Reranker)? = nil) -> HybridSearcher {
        HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: FakeEmbedder(), reranker: reranker)
    }

    @Test func embedsPendingChunksOnceAndSkipsNoneLabel() async throws {
        let (_, database, _) = try await seeded()
        let job = EmbeddingJob(database: database, embedder: FakeEmbedder(), batchSize: 2)
        let first = try await job.run()
        #expect(first.embedded == 6)
        #expect(try await job.pendingCount() == 0)
        #expect(try await job.run().embedded == 0)
        let none = try await database.pool.read { db in
            try Int.fetchOne(db, sql: """
                SELECT count(*) FROM chunk_vectors v JOIN chunks c ON c.id = v.chunk JOIN objects o ON o.rowid = c.obj
                WHERE o.path = 'Notes/Unembedded.md'
                """)
        }
        #expect(none == 0)
        let changed = try await EmbeddingJob(database: database, embedder: FakeEmbedder(modelID: "fake-2")).run()
        #expect(changed.cleared == 6 && changed.embedded == 6)
    }

    @Test func editedNotesAreReembedded() async throws {
        let (temp, database, indexer) = try await seeded()
        let job = EmbeddingJob(database: database, embedder: FakeEmbedder())
        _ = try await job.run()
        try temp.put("Notes/Dogs.md", "# Pets\nThe puppy chews everything.\n")
        _ = try await indexer.update(paths: ["Notes/Dogs.md"])
        #expect(try await job.pendingCount() == 1)
        #expect(try await job.run().embedded == 1)
    }

    @Test func vectorsFindWhatKeywordsMiss() async throws {
        let (_, database, _) = try await seeded()
        _ = try await EmbeddingJob(database: database, embedder: FakeEmbedder()).run()
        let search = searcher(database)
        var options = HybridOptions()
        options.mode = .bm25
        #expect(try await search.search("automobile", options: options).hits.isEmpty)
        options.mode = .vector
        let vector = try await search.search("automobile", options: options)
        #expect(vector.hits.contains { $0.path == "Notes/Cars.md" })
        #expect(!vector.hits.contains { $0.path.hasPrefix("AI/") || $0.path == "Notes/Unembedded.md" })
        options.maxLabel = .cloud
        let cloud = try await search.search("automobile", options: options)
        #expect(cloud.hits.first?.path == "Notes/Cars.md")
        #expect(!cloud.hits.contains { $0.path.hasPrefix("Private/") })
    }

    @Test func fusionRewardsAgreementAndRerankerReorders() async throws {
        let (_, database, _) = try await seeded()
        _ = try await EmbeddingJob(database: database, embedder: FakeEmbedder()).run()
        var options = HybridOptions()
        options.useReranker = false
        let fused = try await searcher(database).search("dog brakes", options: options)
        #expect(fused.hits.first?.path == "Notes/Both.md")
        #expect(fused.hits.first?.bm25Rank != nil && fused.hits.first?.vectorRank != nil)
        #expect(fused.timings["total"] != nil && fused.timings["embed"] != nil)

        options.useReranker = true
        let reranked = try await searcher(database, reranker: FakeReranker()).search("brakes", options: options)
        let order = reranked.hits.map(\.path)
        let noise = try #require(order.firstIndex(of: "Notes/Noise.md"))
        #expect(try #require(order.firstIndex(of: "Notes/Cars.md")) < noise)
        #expect(try #require(order.firstIndex(of: "Notes/Both.md")) < noise)
        #expect(reranked.hits[noise].rerankScore == 0)
        #expect(reranked.hits.first?.rerankScore == 1)
    }

    @Test func abstainsWhenNothingIsRelevant() async throws {
        let (_, database, _) = try await seeded()
        _ = try await EmbeddingJob(database: database, embedder: FakeEmbedder()).run()
        var options = HybridOptions()
        options.abstainBelow = 0.5
        let result = try await searcher(database, reranker: FakeReranker()).search("quantum chromodynamics", options: options)
        #expect(result.abstained && result.hits.isEmpty)
        let answered = try await searcher(database, reranker: FakeReranker()).search("winter brakes", options: options)
        #expect(!answered.abstained && answered.hits.first?.path == "Notes/Cars.md")
    }

    @Test func worksWithoutAnEmbedder() async throws {
        let (_, database, _) = try await seeded()
        let plain = HybridSearcher(database: database, vectors: nil, embedder: nil, reranker: nil)
        let result = try await plain.search("brakes")
        #expect(Set(result.hits.map(\.path)) == ["Notes/Cars.md", "Notes/Both.md", "Notes/Noise.md"])
        #expect(result.hits.allSatisfy { $0.vectorRank == nil })
    }
}
