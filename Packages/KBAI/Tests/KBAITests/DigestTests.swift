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
