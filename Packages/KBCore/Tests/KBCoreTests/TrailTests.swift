import Foundation
import Testing
@testable import KBCore

@Suite struct TrailTests {
    @Test func parsesStepsAndCandidates() throws {
        let text = """
            ---
            kind: trail
            status: endorsed
            ---
            # From BM25 to rerankers
            Intro text.
            1. [[BM25]] — where keyword search starts.
            2. [[Notes/Hybrid retrieval#Results|Hybrid]] – adding vectors.
            - [[Rerankers]]: the last step
            3. Not a step [[Other]]
            """
        let trail = try #require(Trail.parse(text, path: "Notes/Trails/x.md"))
        #expect(trail.title == "From BM25 to rerankers" && trail.endorsed)
        #expect(trail.steps.map(\.target) == ["BM25", "Notes/Hybrid retrieval#Results", "Rerankers"])
        #expect(trail.steps.map(\.sentence) == ["where keyword search starts.", "adding vectors.", "the last step"])
        #expect(trail.steps[0].line == 7)
        #expect(Trail.parse("# no kind\n1. [[A]]", path: "a.md") == nil)

        let lines = Trail.candidate(title: "Untitled trail", targets: ["Notes/A", "Notes/B"], date: "2026-11-09", source: "a Q&A")
        let candidate = try #require(Trail.parse(lines.joined(separator: "\n"), path: "Notes/Trails/Untitled trail.md"))
        #expect(!candidate.endorsed && candidate.steps.map(\.target) == ["Notes/A", "Notes/B"] && candidate.steps.allSatisfy { $0.sentence.isEmpty })
    }
}
