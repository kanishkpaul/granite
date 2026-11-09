import Foundation
import KBCore
import KBIndex
import Testing
@testable import KBAI

func hit(_ path: String, _ text: String, rerank: Double? = 0.8, label: String = "cloud") -> HybridHit {
    HybridHit(chunk: 1, path: path, title: NoteParser.title(for: path), type: "note", origin: "human", headingPath: "",
              text: text, startLine: 1, endLine: 1, blockID: nil, aiLabel: label, bm25Rank: 1, vectorRank: 1, fused: 0.03,
              rerankScore: rerank)
}

@Suite struct VerifierTests {
    let passage = "Hybrid search (BM25 plus vectors) followed by a **reranker** matters more than the embedding model."

    @Test func exactAndNormalizedQuotes() {
        #expect(Verifier.supports(quote: "followed by a reranker matters more", passage: passage))
        #expect(Verifier.supports(quote: "HYBRID SEARCH — BM25 plus vectors", passage: passage))
        #expect(!Verifier.supports(quote: "the embedding model matters most", passage: passage))
        #expect(!Verifier.supports(quote: "ok", passage: passage))
    }

    @Test func tokenOverlapNeedsNinetyPercent() {
        // 9 of 10 words present → passes; 8 of 10 → fails.
        #expect(Verifier.supports(quote: "reranker matters more than the embedding model plus vectors zebra", passage: passage))
        #expect(!Verifier.supports(quote: "reranker matters more than the embedding model zebra yak", passage: passage))
    }

    @Test func unknownSourceIsUnverified() {
        let docs = [SourceDocument(id: "c1", title: "t", text: passage)]
        #expect(!Verifier.check(text: "x", sourceID: "c9", quote: "Hybrid search", documents: docs).verified)
        #expect(Verifier.check(text: "x", sourceID: "c1", quote: "Hybrid search (BM25", documents: docs).verified)
    }
}

@Suite struct GroundedQATests {
    func service(_ providers: [any LanguageProvider]) -> ModelService { ModelService(providers: providers, state: nil) }

    @Test func abstainsBelowThresholdWithoutCallingAModel() async throws {
        let device = FakeProvider(.onDevice, results: [])
        let qa = GroundedQA(models: service([device])) { _ in
            HybridResult(hits: [hit("Notes/a.md", "unrelated", rerank: 0.001)], abstained: false, timings: [:])
        }
        let answer = try await qa.ask("capital of mongolia?")
        #expect(answer.abstained && answer.sentences.isEmpty && device.calls == 0)
        let empty = GroundedQA(models: service([device])) { _ in HybridResult(hits: [], abstained: false, timings: [:]) }
        #expect(try await empty.ask("anything").abstained)
    }

    @Test func onDeviceAnswerIsVerifiedPerSentence() async throws {
        let json = """
        {"sentences": [
          {"text": "Hybrid retrieval beats tuning embeddings.", "source": "c1", "quote": "reranker matters more than the embedding model"},
          {"text": "It also cures cancer.", "source": "c1", "quote": "cures cancer"},
          {"text": "Bad id.", "source": "c7", "quote": "Hybrid search"}]}
        """
        let device = FakeProvider(.onDevice, results: [.success(Generation(text: json, inputTokens: 1, outputTokens: 1, model: "apple"))])
        let qa = GroundedQA(models: service([device])) { _ in
            HybridResult(hits: [hit("Notes/Hybrid.md", "Hybrid search plus a reranker matters more than the embedding model.", label: "local")],
                         abstained: false, timings: [:])
        }
        let answer = try await qa.ask("what matters for retrieval?")
        #expect(answer.route == .onDevice && answer.label == .local)
        #expect(answer.sentences.map(\.verified) == [true, false, false])
        #expect(answer.verifiedCount == 1 && !answer.abstained)
    }

    @Test func modelSayingNotAnsweredAbstains() async throws {
        let device = FakeProvider(.onDevice, results: [.success(Generation(text: #"{"sentences": []}"#,
                                                                           inputTokens: 1, outputTokens: 1, model: "apple"))])
        let qa = GroundedQA(models: service([device])) { _ in
            HybridResult(hits: [hit("Notes/a.md", "something")], abstained: false, timings: [:])
        }
        #expect(try await qa.ask("q").abstained)
    }

    @Test func claudeCitationsBecomeSentences() async throws {
        let generation = Generation(text: "Hybrid wins. And something uncited that sounds plausible.",
                                    citations: [NativeCitation(documentID: "c1", citedText: "Hybrid search plus a reranker",
                                                               sentence: "Hybrid wins.")],
                                    inputTokens: 1, outputTokens: 1, model: "claude-haiku-5-5")
        let haiku = FakeProvider(.haiku, results: [.success(generation)])
        let qa = GroundedQA(models: service([haiku])) { _ in
            HybridResult(hits: [hit("Notes/Hybrid.md", "Hybrid search plus a reranker matters more.")], abstained: false, timings: [:])
        }
        let answer = try await qa.ask("what wins?")
        #expect(answer.route == .haiku)
        #expect(answer.sentences.first == AnswerSentence(text: "Hybrid wins.", sourceID: "c1",
                                                         quote: "Hybrid search plus a reranker", verified: true))
        #expect(answer.sentences.last?.verified == false)
    }

    @Test func privateLabelsKeepAnswersOffTheCloud() async throws {
        let haiku = FakeProvider(.haiku, results: [])
        let device = FakeProvider(.onDevice, results: [.success(Generation(text: #"{"sentences": []}"#,
                                                                           inputTokens: 1, outputTokens: 1, model: "apple"))])
        let qa = GroundedQA(models: service([haiku, device])) { _ in
            HybridResult(hits: [hit("Notes/a.md", "x"), hit("Private/diary.md", "y", label: "local")], abstained: false, timings: [:])
        }
        _ = try await qa.ask("q")
        #expect(haiku.calls == 0 && device.calls == 1)
    }

    @Test func weakPassagesAreDroppedBeforeLabelling() async throws {
        let haiku = FakeProvider(.haiku, results: [.success(Generation(text: "ok", inputTokens: 1, outputTokens: 1,
                                                                       model: "claude-haiku-5-5"))])
        let qa = GroundedQA(models: service([haiku])) { _ in
            HybridResult(hits: [hit("Notes/a.md", "relevant", rerank: 0.9), hit("Daily/d.md", "noise", rerank: 0.01, label: "pcc")],
                         abstained: false, timings: [:])
        }
        let answer = try await qa.ask("q")
        #expect(answer.route == .haiku && answer.label == .cloud && answer.sources.count == 1)
    }
}
