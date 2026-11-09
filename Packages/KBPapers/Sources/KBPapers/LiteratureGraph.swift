import Foundation
import KBCore

/// A paper near a seed in the citation graph.
public struct GraphCandidate: Sendable, Equatable {
    public enum Relation: String, Sendable { case reference, citedBy = "cited by" }
    public let record: PaperRecord
    public let relation: Relation
    /// Closeness to your notes and claims (cosine, or a keyword score), and the closest note.
    public var score: Double?
    public var nearest: String?
}

/// Literature-graph expansion (master plan §7, idea 9): from a seed paper, its OpenAlex references
/// and the works citing it, ranked by how close they are to what you've written. Two requests
/// per seed (singleton lookups); papers already in the vault are left out.
public struct LiteratureGraph: Sendable {
    public typealias Scorer = @Sendable (String) async -> (score: Double, nearest: String?)?
    let client: ScholarlyClient

    public init(client: ScholarlyClient = ScholarlyClient()) {
        self.client = client
    }

    public func expand(seedID: String?, doi: String?, knownDOIs: Set<String>, limit: Int = 25,
                       scorer: Scorer?) async throws -> (seed: PaperRecord, candidates: [GraphCandidate]) {
        var seed: PaperRecord?
        if let doi, !doi.isEmpty { seed = try await client.openAlex(doi: doi) }
        if seed == nil, let seedID { seed = try await client.openAlexWorks([seedID]).first }
        guard let seed, let id = seed.openAlexID else { throw EnrichmentError.notFound }
        async let references = client.openAlexWorks(Array(seed.references.prefix(50)))
        async let citing = client.openAlexCitedBy(id, limit: limit)
        var candidates = try await references.map { GraphCandidate(record: $0, relation: .reference) }
            + citing.map { GraphCandidate(record: $0, relation: .citedBy) }
        let known = Set(knownDOIs.map { $0.lowercased() })
        candidates = candidates.filter { candidate in
            candidate.record.doi.map { !known.contains($0.lowercased()) } ?? true
        }
        if let scorer {
            for index in candidates.indices {
                let record = candidates[index].record
                let text = [record.title, record.abstract].compactMap { $0 }.joined(separator: "\n")
                if let result = await scorer(text) {
                    candidates[index].score = result.score
                    candidates[index].nearest = result.nearest
                }
            }
        }
        candidates.sort { ($0.score ?? -1, $0.record.citedBy ?? 0) > ($1.score ?? -1, $1.record.citedBy ?? 0) }
        return (seed, candidates)
    }

    /// `AI/Reading/<citekey> graph.md`: the ranked list, as AI output that cites nothing private.
    public static func render(seedTitle: String, citekey: String, candidates: [GraphCandidate], date: String, limit: Int = 15) -> String {
        var lines = ["---", "type: synthesis", "kind: reading-list", "origin: ai", "model: none", "ai: cloud",
                     "seed: \"[[Papers/\(citekey)]]\"", "created: \(date)", "---",
                     "# Around \(seedTitle)", "",
                     "Papers that \(citekey) cites or that cite it (OpenAlex), ranked by closeness to your notes. Not read, not trusted: candidates.", ""]
        for relation in [GraphCandidate.Relation.reference, .citedBy] {
            let group = candidates.filter { $0.relation == relation }.prefix(limit)
            guard !group.isEmpty else { continue }
            lines.append(relation == .reference ? "## It cites" : "## Cited by")
            for candidate in group {
                let record = candidate.record
                var parts = ["**\(record.title ?? "Untitled")**"]
                var facts: [String] = []
                if let year = record.year { facts.append(String(year)) }
                if let venue = record.venue { facts.append(venue) }
                if !facts.isEmpty { parts.append("(\(facts.joined(separator: ", ")))") }
                if let citedBy = record.citedBy { parts.append("· cited by \(citedBy)") }
                if let doi = record.doi { parts.append("· [doi](https://doi.org/\(doi))") }
                if let nearest = candidate.nearest, let score = candidate.score {
                    parts.append(String(format: "· closest: [[%@|%@]] (%.2f)", String(nearest.dropLast(3)), NoteParser.title(for: nearest), score))
                }
                lines.append("- " + parts.joined(separator: " "))
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
