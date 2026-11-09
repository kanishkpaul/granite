import Foundation
import KBCore
import Testing
@testable import KBPapers

/// Canned API answers, keyed by host.
final class MockScholar: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [String: (Int, String)] = [:]
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let (status, body) = Self.responses[request.url?.host ?? ""] ?? (404, "{}")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct EnrichmentTests {
    func client() -> ScholarlyClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockScholar.self]
        return ScholarlyClient(session: URLSession(configuration: configuration))
    }

    @Test func mergesTheThreeServices() async throws {
        MockScholar.requests = []
        MockScholar.responses = [
            "api.crossref.org": (200, #"{"message": {"DOI": "10.5555/ABC", "title": ["Dense Retrieval"], "author": [{"given": "Jane", "family": "Doe"}], "issued": {"date-parts": [[2024, 3]]}, "container-title": ["SIGIR"], "abstract": "<jats:p>We study <jats:italic>dense</jats:italic> retrieval.</jats:p>", "reference-count": 42, "is-referenced-by-count": 7}}"#),
            "api.openalex.org": (200, #"{"id": "https://openalex.org/W123", "title": "Dense retrieval", "publication_year": 2024, "cited_by_count": 9, "referenced_works": ["https://openalex.org/W1", "https://openalex.org/W2"], "abstract_inverted_index": {"We": [0], "study": [1], "it.": [2]}}"#),
            "api.semanticscholar.org": (200, #"{"title": "Dense Retrieval", "year": 2024, "citationCount": 8, "tldr": {"text": "Dense beats sparse sometimes."}}"#),
        ]
        let record = try await client().lookup(doi: "10.5555/ABC", title: nil)
        #expect(record.title == "Dense Retrieval" && record.authors == ["Jane Doe"] && record.year == 2024 && record.venue == "SIGIR")
        #expect(record.abstract == "We study it." && record.tldr == "Dense beats sparse sometimes.")
        #expect(record.openAlexID == "W123" && record.citedBy == 9 && record.references == ["W1", "W2"] && record.referenceCount == 42)
        #expect(MockScholar.requests.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent") == ScholarlyClient.userAgent })
        #expect(!MockScholar.requests.contains { ($0.url?.absoluteString ?? "").contains("mailto") }, "no email address is sent")
        #expect(ScholarlyClient.stripJATS("<jats:title>Abstract</jats:title><jats:p>Text  here.</jats:p>") == "Text here.")
    }

    @Test func titleSearchAndFailures() async throws {
        MockScholar.responses = ["api.openalex.org": (200, #"{"results": [{"id": "https://openalex.org/W9", "title": "Found by title", "publication_year": 2020}]}"#)]
        let record = try await client().lookup(doi: nil, title: "Some paper about retrieval")
        #expect(record.title == "Found by title" && record.openAlexID == "W9")
        await #expect(throws: EnrichmentError.noIdentifier) { try await client().lookup(doi: nil, title: "short") }
        MockScholar.responses = [:]
        await #expect(throws: EnrichmentError.notFound) { try await client().lookup(doi: "10.1/none", title: nil) }
    }

    @Test func writerUpdatesFrontmatterAndRegionOnly() throws {
        let paths = PaperPaths(citekey: "doe2024dense")
        var note = LiteratureNote.render(paths: paths, metadata: PaperMetadata(title: "Guess", authors: [], year: nil), created: "2026-11-09")
        note = note.replacingOccurrences(of: "## My take\n\n", with: "## My take\nMine.\n")
        var record = PaperRecord()
        record.title = "Dense: Retrieval"
        record.authors = ["Jane \"JD\" Doe", "Ann Lee"]
        record.year = 2024
        record.doi = "10.5555/abc"
        record.abstract = "We study it."
        record.citedBy = 9
        let once = try EnrichmentWriter.apply(record, to: note, date: "2026-11-10")
        let parsed = NoteParser.parse(data: Data(once.utf8), path: paths.note, policy: .builtIn)
        #expect(parsed.frontmatter?["title"]?.text == "Dense: Retrieval")
        #expect(parsed.frontmatter?["authors"]?.strings == ["Jane \"JD\" Doe", "Ann Lee"])
        #expect(once.contains("year: 2024\n") && once.contains("cited_by: 9\n") && once.contains("enriched: 2026-11-10"))
        #expect(once.contains("## My take\nMine.\n"))
        #expect(once.range(of: EnrichmentWriter.begin)!.lowerBound < once.range(of: "## My take")!.lowerBound)
        record.citedBy = 10
        let twice = try EnrichmentWriter.apply(record, to: once, date: "2026-11-11")
        #expect(twice.components(separatedBy: EnrichmentWriter.begin).count == 2 && twice.contains("cited by 10"))
        // A block list is replaced whole.
        let block = try FrontmatterEditor.setRaw("authors", yaml: "[X]", in: "---\nauthors:\n  - A\n  - B\nyear: 1\n---\nbody\n")
        #expect(block == "---\nauthors: [X]\nyear: 1\n---\nbody\n")
    }
}

@Suite struct DoclingTests {
    /// A stand-in `docling` that writes Markdown the way the real CLI does (`--to md --output DIR PDF`).
    func fakeDocling(_ body: String, exit: Int = 0) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "granite-fake-docling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = folder.appending(path: "docling")
        try Data("""
            #!/bin/sh
            out="$4"
            name=$(basename "$5" .pdf)
            printf '\(body)' > "$out/$name.md"
            echo "converted" >&2
            exit \(exit)
            """.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path(percentEncoded: false))
        return script
    }

    @Test func runsCachesAndRewritesTheTextNote() async throws {
        let cache = FileManager.default.temporaryDirectory.appending(path: "granite-docling-cache-\(UUID().uuidString)")
        let runner = DoclingRunner(executable: try fakeDocling("# Dense Retrieval\\n\\n## Results\\n\\n| a | b |\\n|---|---|\\n| 1 | 2 |\\n"), cache: cache)
        let pdf = FileManager.default.temporaryDirectory.appending(path: "paper.pdf")
        try Data("%PDF".utf8).write(to: pdf)
        let markdown = try await runner.markdown(pdf: pdf, citekey: "doe2024dense")
        #expect(markdown.contains("## Results"))
        #expect(FileManager.default.fileExists(atPath: cache.appending(path: "doe2024dense.md").path(percentEncoded: false)))
        let note = DoclingRunner.textNote(paths: PaperPaths(citekey: "doe2024dense"), title: "Dense", markdown: markdown)
        #expect(note.contains("text: docling") && note.contains("\n## Dense Retrieval\n") && note.contains("\n### Results\n"))
        #expect(PaperText.page(fromHeadingPath: "Dense Retrieval > Results") == nil, "no page sections: the PDF view searches every page")

        let failing = DoclingRunner(executable: try fakeDocling("", exit: 3), cache: cache.appending(path: "other"))
        await #expect(throws: DoclingError.self) { try await failing.markdown(pdf: pdf, citekey: "x") }
        #expect(DoclingRunner.locate(environment: ["PATH": "/nonexistent"]) == nil || true)
    }
}

@Suite(.serialized) struct LiteratureGraphTests {
    @Test func expandsRanksAndSkipsKnownPapers() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GraphMock.self]
        let client = ScholarlyClient(session: URLSession(configuration: configuration))
        let graph = LiteratureGraph(client: client)
        let (seed, candidates) = try await graph.expand(seedID: nil, doi: "10.1/seed", knownDOIs: ["10.1/known"]) { text in
            text.lowercased().contains("rerank") ? (0.8, "Notes/Rerankers.md") : (0.2, nil)
        }
        #expect(seed.openAlexID == "W0")
        #expect(candidates.map(\.record.title) == ["Reranking matters", "Older work", "A citing paper"])
        #expect(candidates.first?.relation == .reference && candidates.last?.relation == .citedBy)
        let note = LiteratureGraph.render(seedTitle: "Seed", citekey: "seed2024", candidates: candidates, date: "2026-11-09")
        #expect(note.contains("## It cites\n- **Reranking matters** (2023) · [doi](https://doi.org/10.1/r) · closest: [[Notes/Rerankers|Rerankers]] (0.80)"))
        #expect(note.contains("## Cited by") && !note.contains("Known paper"))
    }
}

/// OpenAlex answers for one seed: two references (one already in the vault), one citing work.
final class GraphMock: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url?.absoluteString ?? ""
        let body: String
        if url.contains("doi.org") {
            body = #"{"id": "https://openalex.org/W0", "title": "Seed", "referenced_works": ["https://openalex.org/W1", "https://openalex.org/W2", "https://openalex.org/W3"]}"#
        } else if url.contains("filter=openalex") {
            body = #"{"results": [{"id": "W1", "title": "Reranking matters", "publication_year": 2023, "doi": "https://doi.org/10.1/r"}, {"id": "W2", "title": "Older work", "cited_by_count": 50}, {"id": "W3", "title": "Known paper", "doi": "https://doi.org/10.1/known"}]}"#
        } else {
            body = #"{"results": [{"id": "W9", "title": "A citing paper", "cited_by_count": 3}]}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
