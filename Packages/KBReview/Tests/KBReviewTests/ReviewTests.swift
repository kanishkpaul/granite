import Foundation
import KBCore
import KBIndex
import Testing
@testable import KBReview

@Suite struct FSRSTests {
    let fsrs = FSRS()
    let start = Date(timeIntervalSince1970: 1_794_214_925)

    @Test func firstReviewsFollowTheDefaults() {
        let good = fsrs.review(nil, grade: .good, now: start)
        #expect(abs(good.stability - 3.173) < 1e-9)
        #expect(good.due.timeIntervalSince(start) / 86_400 == 3)
        let again = fsrs.review(nil, grade: .again, now: start)
        #expect(again.due.timeIntervalSince(start) == 600 && again.lapses == 1)
        let easy = fsrs.review(nil, grade: .easy, now: start)
        #expect(easy.due.timeIntervalSince(start) / 86_400 == 16)
        #expect(fsrs.initialDifficulty(.easy) < fsrs.initialDifficulty(.good))
        #expect(fsrs.initialDifficulty(.good) < fsrs.initialDifficulty(.again))
    }

    @Test func retrievabilityIsNinetyPercentAtTheInterval() {
        #expect(abs(fsrs.retrievability(days: 10, stability: 10) - 0.9) < 1e-9)
        #expect(fsrs.interval(stability: 10) == 10)
    }

    @Test func successGrowsIntervalsAndLapsesShrinkThem() {
        var card = fsrs.review(nil, grade: .good, now: start)
        var intervals: [Double] = []
        for _ in 0..<4 {
            let next = fsrs.review(card, grade: .good, now: card.due)
            intervals.append(next.due.timeIntervalSince(card.due) / 86_400)
            card = next
        }
        #expect(intervals == intervals.sorted() && intervals.last! > 30)
        let lapse = fsrs.review(card, grade: .again, now: card.due)
        #expect(lapse.stability < card.stability && lapse.lapses == 1 && lapse.difficulty > card.difficulty)
        let hard = fsrs.review(card, grade: .hard, now: card.due)
        let easy = fsrs.review(card, grade: .easy, now: card.due)
        #expect(hard.stability < easy.stability)
    }
}

@Suite struct PromptTests {
    @Test func parsesCalloutsWithAndWithoutIDs() {
        let text = """
            ---
            id: 01JC9Q7Z5W3K8M2R4T6V8X0Y1A
            ---
            Intro.

            > [!prompt] What beats embedding choice?
            > Hybrid search
            > plus a reranker. ^p-k7h2qx

            > [!note] Not a prompt

            > [!prompt]- Why chunk by headings?
            > Sections are units of meaning.
            """
        let prompts = PromptParser.prompts(in: text, path: "Notes/a.md")
        #expect(prompts.count == 2)
        #expect(prompts[0].question == "What beats embedding choice?" && prompts[0].answer == "Hybrid search\nplus a reranker.")
        #expect(prompts[0].key == "01JC9Q7Z5W3K8M2R4T6V8X0Y1A#^p-k7h2qx" && prompts[0].line == 6)
        #expect(prompts[1].question == "Why chunk by headings?" && prompts[1].key == nil)
        let rendered = PromptParser.render(question: "Q?", answer: "A1\nA2", blockID: "p-abc")
        #expect(rendered == ["> [!prompt] Q?", "> A1", "> A2 ^p-abc"])
        #expect(PromptParser.prompts(in: rendered.joined(separator: "\n"), path: "x.md").first?.answer == "A1\nA2")
    }

    @Test func logRoundTripsAndReplaysInTimeOrder() {
        let t = Date(timeIntervalSince1970: 1_794_214_925)
        let events = [ReviewEvent(ts: t.addingTimeInterval(86_400 * 3), prompt: "k", grade: .good, seconds: 4.5),
                      ReviewEvent(ts: t, prompt: "k", grade: .good)]
        let text = events.map(ReviewLog.line).joined(separator: "\n") + "\nnot json\n"
        let parsed = ReviewLog.events(in: text)
        #expect(parsed == events)
        let card = ReviewLog.replay(parsed)["k"]
        #expect(card?.reviews == 2 && card?.lastReview == t.addingTimeInterval(86_400 * 3))
    }
}

@Suite struct ReviewQueueTests {
    func vault() throws -> (Vault, URL) {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-review-\(UUID().uuidString)")
        let root = base.appending(path: "vault")
        try FileManager.default.createDirectory(at: root.appending(path: "Notes"), withIntermediateDirectories: true)
        try Data("""
            > [!prompt] What beats embedding choice?
            > Hybrid plus rerank. ^p-aaaaaa

            > [!prompt] Why chunk by headings?
            > Sections carry meaning.
            """.utf8).write(to: root.appending(path: "Notes/Retrieval.md"))
        try FileManager.default.createDirectory(at: root.appending(path: "AI/Synthesis"), withIntermediateDirectories: true)
        try Data("> [!prompt] AI prompt\n> skipped ^p-bbbbbb\n".utf8).write(to: root.appending(path: "AI/Synthesis/x.md"))
        return (Vault(root: root), base.appending(path: "index.sqlite"))
    }

    @Test func dueNewGradeAndStats() async throws {
        let (vault, db) = try vault()
        let indexer = Indexer(database: try IndexDatabase(url: db), vault: vault, policy: .builtIn)
        _ = try await indexer.reconcile()
        let queue = ReviewQueue(indexer: indexer, writer: SafeWriter(vault: vault), newPerDay: 10)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date(timeIntervalSince1970: 1_794_214_925)

        let first = try await queue.due(now: now, calendar: calendar)
        #expect(first.count == 2 && first.allSatisfy { $0.card == nil })

        // Grading the prompt without an id gives it one and logs the review.
        let unnamed = try #require(first.first { $0.prompt.key == nil })
        let state = try await queue.grade(unnamed.prompt, .good, seconds: 3, now: now)
        #expect(state.reviews == 1)
        let note = try String(contentsOf: vault.url(for: "Notes/Retrieval.md"), encoding: .utf8)
        #expect(note.range(of: #"Sections carry meaning\. \^p-[a-z0-9]{6}"#, options: .regularExpression) != nil)
        let log = try String(contentsOf: vault.url(for: ReviewLog.path), encoding: .utf8)
        #expect(log.contains("\"grade\":3") && log.contains("Notes/Retrieval.md#^p-"))

        let named = try #require(first.first { $0.prompt.key != nil })
        try await queue.grade(named.prompt, .again, now: now)
        let later = try await queue.due(now: now.addingTimeInterval(700), calendar: calendar)
        #expect(later.map(\.prompt.question) == ["What beats embedding choice?"], "the lapse is due again; the good one is not")
        let stats = try await queue.stats(now: now.addingTimeInterval(700))
        #expect(stats.total == 2 && stats.due == 1 && stats.new == 0 && stats.reviewed == 2 && stats.recall == 0.5)

        // The daily allowance of new prompts counts first reviews made today.
        let strict = ReviewQueue(indexer: indexer, writer: SafeWriter(vault: vault), newPerDay: 0)
        try Data("> [!prompt] Third?\n> Yes.\n".utf8).write(to: vault.url(for: "Notes/More.md"))
        _ = try await indexer.update(paths: ["Notes/More.md"])
        #expect(try await strict.due(now: now.addingTimeInterval(700), calendar: calendar).count == 1)
    }
}
