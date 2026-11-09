import Foundation
import KBCore
import KBIndex
import Testing
@testable import KBAI

@Suite struct DigestTests {
    func vault() async throws -> (Indexer, SafeWriter, URL) {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-digest-\(UUID().uuidString)")
        let root = base.appending(path: "vault")
        for (path, text) in [
            "Notes/Retrieval.md": "# Retrieval\nHybrid search plus reranking wins. Does it hold for short queries? [[Rerankers]]\n",
            "Notes/Rerankers.md": "Rerankers are slow but precise.\n> [!question] Which reranker is fastest?\n```\nnot a question in code?\n```\n",
            "Private/diary.md": "---\nai: none\n---\nSecret diary entry?\n",
            "Notes/Orphan.md": "Nobody links here.\n",
        ] {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        let vault = Vault(root: root)
        let indexer = Indexer(database: try IndexDatabase(url: base.appending(path: "index.sqlite")), vault: vault, policy: .builtIn)
        _ = try await indexer.reconcile()
        return (indexer, SafeWriter(vault: vault), root)
    }

    @Test func writesADigestWithCitationsQuestionsAndLint() async throws {
        let (indexer, writer, root) = try await vault()
        let reply = #"{"sentences": [{"source": "n1", "text": "Reranking is precise but slow."}]}"#
        let provider = FakeProvider(.onDevice, results: Array(repeating: .success(Generation(text: reply, inputTokens: 1, outputTokens: 1, model: "fake")), count: 5))
        let job = DigestJob(models: ModelService(providers: [provider], state: nil), indexer: indexer, writer: writer)
        let now = Date()
        let result = try await job.run(since: now.addingTimeInterval(-3600), now: now)
        let text = try String(contentsOf: root.appending(path: result.path), encoding: .utf8)
        #expect(result.path.hasPrefix("AI/Digests/") && result.changed == 3 && result.summarizedBy == "fake")
        #expect(text.contains("type: digest") && text.contains("origin: ai"))
        #expect(text.contains("Reranking is precise but slow. [[Notes/"))
        #expect(text.contains("- Does it hold for short queries? — [[Notes/Retrieval|Retrieval]]"))
        #expect(text.contains("- Which reranker is fastest? — [[Notes/Rerankers|Rerankers]]"))
        #expect(!text.contains("not a question in code") && !text.contains("Secret diary"), "code and `none` notes stay out")
        #expect(text.contains("### Orphan (1)") && text.contains("[[Notes/Orphan|Orphan]]") && !text.contains("diary"))
        #expect(text.contains("ai: cloud"))
        // The digest is indexed but never counts as a link into your notes.
        #expect(try VaultLint(database: indexer.database).run().contains { $0.rule == .orphan && $0.path == "Notes/Orphan.md" })
    }

    @Test func worksWithoutAModel() async throws {
        let (indexer, writer, root) = try await vault()
        let result = try await DigestJob(models: nil, indexer: indexer, writer: writer).run(since: .distantPast)
        let text = try String(contentsOf: root.appending(path: result.path), encoding: .utf8)
        #expect(result.summarizedBy == nil && text.contains("model: none"))
        #expect(text.contains("[[Notes/Retrieval|Retrieval]]: Hybrid search plus reranking wins."))
    }
}

@Suite struct BeliefTests {
    @Test func beliefDiffListsAndNarrates() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-beliefs-\(UUID().uuidString)")
        let root = base.appending(path: "vault")
        let day = ProposalStore.day(Date(), .current)
        for (path, text) in [
            "Notes/Old view.md": "---\ntype: claim\nstatus: superseded\ncreated: 2025-01-01\nas_of: \(day)\n---\nEmbeddings matter most.\n",
            "Notes/New view.md": "---\ntype: claim\nstatus: held\ncreated: \(day)\nas_of: \(day)\nsupersedes: [\"[[Old view]]\"]\n---\nRerankers matter most.\n",
            "Notes/Steady.md": "---\ntype: claim\nstatus: held\ncreated: 2024-01-01\nas_of: 2024-01-01\n---\nWrite every day.\n",
        ] {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        let indexer = Indexer(database: try IndexDatabase(url: base.appending(path: "index.sqlite")), vault: Vault(root: root), policy: .builtIn)
        _ = try await indexer.reconcile()
        let reply = #"{"sentences": [{"claims": ["k1", "k2"], "text": "You moved from embeddings to rerankers."}]}"#
        let models = ModelService(providers: [FakeProvider(.onDevice, results: [.success(Generation(text: reply, inputTokens: 1, outputTokens: 1, model: "fake"))])],
                                  state: nil)
        let (path, text, model) = try await BeliefDiff(models: models, database: indexer.database).render(labels: { _ in .cloud })
        #expect(path.hasPrefix("AI/Synthesis/Belief diff ") && model == "fake")
        #expect(text.contains("1 new, 0 revised, 1 superseded, 0 retired; 1 held throughout."))
        #expect(text.contains("- [[Notes/New view|New view]] (\(day)) ← replaced [[Notes/Old view|Old view]]"))
        #expect(text.contains("You moved from embeddings to rerankers. [[Notes/"))
        #expect(BeliefDiff.quarter(of: Date(timeIntervalSince1970: 1_794_214_925)).label == "2026-Q4")
    }

    @Test func nliVerdicts() async throws {
        let reply = #"{"reason": "Both can't hold.", "relation": "Contradicts"}"#
        let models = ModelService(providers: [FakeProvider(.onDevice, results: [.success(Generation(text: reply, inputTokens: 1, outputTokens: 1, model: "fake"))])],
                                  state: nil)
        let (relation, reason) = try await NLIChecker(models: models).check("A is true.", "A is false.", labels: [.local], paths: [])
        #expect(relation == .contradicts && reason == "Both can't hold.")
    }
}

@Suite struct WikiTests {
    @Test func buildsVerifiedPagesFromSourcesOnly() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-wiki-\(UUID().uuidString)")
        let root = base.appending(path: "vault")
        for (path, text) in [
            "Papers/bm25.md": "---\ntype: source\nkind: paper\n---\n# BM25\n## Saturation\nBM25 saturates term frequency with the k1 parameter.\n",
            "Clippings/rerank.md": "---\ntype: clipping\n---\n# Rerankers\nCross-encoders rerank the top candidates for precision.\n",
            "Notes/My view.md": "BM25 saturates term frequency but I think it is overrated.\n",
        ] {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        let vault = Vault(root: root)
        let indexer = Indexer(database: try IndexDatabase(url: base.appending(path: "index.sqlite")), vault: vault, policy: .builtIn)
        _ = try await indexer.reconcile()
        let topics = #"{"topics": ["Saturation", "Reranking"]}"#
        let page1 = #"{"sentences": [{"source": "c1", "quote": "BM25 saturates term frequency with the k1 parameter", "text": "BM25 caps the effect of repeated terms."}, {"source": "c1", "quote": "invented words", "text": "Unsupported claim."}]}"#
        let page2 = #"{"sentences": []}"#
        let provider = FakeProvider(.onDevice, results: [topics, page1, page2].map { .success(Generation(text: $0, inputTokens: 1, outputTokens: 1, model: "fake")) })
        let searcher = HybridSearcher(database: indexer.database, vectors: nil, embedder: nil, reranker: nil)
        let builder = WikiBuilder(models: ModelService(providers: [provider], state: nil), indexer: indexer,
                                  writer: SafeWriter(vault: vault), searcher: searcher)
        let domain = WikiDomain(name: "Retrieval")
        #expect(try builder.sources(for: domain).map(\.path) == ["Clippings/rerank.md", "Papers/bm25.md"])
        let report = try await builder.build(domain)
        #expect(report.sources == 2 && report.localModel)
        #expect(report.pages.first == "AI/Wiki/Retrieval/index.md")
        let page = try String(contentsOf: root.appending(path: "AI/Wiki/Retrieval/Saturation.md"), encoding: .utf8)
        #expect(page.contains("BM25 caps the effect of repeated terms. [[Papers/bm25#Saturation|bm25]]"))
        #expect(!page.contains("Unsupported claim") && page.contains("[!warning]") && !page.contains("My view"))
        #expect(report.skippedTopics == ["Reranking"])
        let index = try String(contentsOf: root.appending(path: "AI/Wiki/Retrieval/index.md"), encoding: .utf8)
        #expect(index.contains("[[AI/Wiki/Retrieval/Saturation|Saturation]]") && index.contains("Not enough in the sources for: Reranking."))
    }
}
