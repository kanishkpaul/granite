import Foundation
import KBCore
import Testing
@testable import KBIndex

@Suite struct ClaimServiceTests {
    let now = Date(timeIntervalSince1970: 1_794_214_925)  // 2026-11-09

    func service(_ temp: TempVault) async throws -> ClaimService {
        try temp.put("Notes/Retrieval.md", "# Retrieval\nReranking matters more than the embedding model.\nWe saw it twice.\n\n## Later\nOther text.\n")
        let (_, indexer) = try temp.indexer()
        _ = try await indexer.reconcile()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return ClaimService(indexer: indexer, writer: SafeWriter(vault: temp.vault), calendar: utc)
    }

    func read(_ temp: TempVault, _ path: String) throws -> String {
        try String(contentsOf: temp.root.appending(path: path), encoding: .utf8)
    }

    @Test func promoteCitesTheSourceBlock() async throws {
        let temp = try TempVault()
        let claims = try await service(temp)
        let path = try await claims.promote("Reranking matters more than the embedding model.", from: "Notes/Retrieval.md", line: 2,
                                            confidence: 0.8, now: now)
        #expect(path == "Notes/Reranking matters more than the embedding model.md")
        let source = try read(temp, "Notes/Retrieval.md")
        let id = try #require(source.range(of: #"\^c-[a-z0-9]{6}"#, options: .regularExpression).map { String(source[$0].dropFirst()) })
        #expect(source.contains("We saw it twice. ^\(id)\n"))
        let claim = try read(temp, path)
        #expect(claim.contains("source: [\"[[Retrieval#^\(id)]]\"]") && claim.contains("confidence: 0.80") && claim.contains("as_of: 2026-11-09"))
        let all = try await claims.claims()
        #expect(all.map(\.path) == [path] && all.first?.status == .held && all.first?.confidence == 0.8)
        await #expect(throws: ClaimError.cannotCite("Notes/Retrieval.md")) {
            try await claims.promote("Heading", from: "Notes/Retrieval.md", line: 1, now: now)
        }
        await #expect(throws: ClaimError.empty) { try await claims.promote("  ", from: "Notes/Retrieval.md", line: 2, now: now) }
    }

    @Test func supersedeKeepsTheOldTextAndBuildsHistory() async throws {
        let temp = try TempVault()
        let claims = try await service(temp)
        let first = try await claims.promote("Reranking matters more than the embedding model.", from: "Notes/Retrieval.md", line: 2, now: now)
        let firstBody = try read(temp, first).components(separatedBy: "---\n").last
        // Same day for all three: the chain order, not the date or the name, decides.
        let later = now
        let second = try await claims.supersede(first, with: "Reranking matters, but only for long queries.", confidence: 0.6, now: later)
        let third = try await claims.supersede(second, with: "A reranker matters for long queries; short ones need BM25.", now: later)
        let old = try read(temp, first)
        #expect(old.contains("status: superseded") && old.components(separatedBy: "---\n").last == firstBody)
        #expect(try read(temp, second).contains("supersedes: [\"[[Reranking matters more than the embedding model]]\"]"))

        for path in [first, second, third] {
            #expect(try await claims.history(of: path).map(\.path) == [first, second, third])
        }
        let statuses = try await claims.history(of: third).map(\.status)
        #expect(statuses == [.superseded, .superseded, .held])
        await #expect(throws: ClaimError.notAClaim("Notes/Retrieval.md")) {
            try await claims.supersede("Notes/Retrieval.md", with: "x", now: now)
        }
    }

    @Test func statusChangesUpdateAsOf() async throws {
        let temp = try TempVault()
        let claims = try await service(temp)
        let path = try await claims.promote("Reranking matters more than the embedding model.", from: "Notes/Retrieval.md", line: 2, now: now)
        try await claims.setStatus(.revised, of: path, now: now.addingTimeInterval(86_400 * 3))
        let text = try read(temp, path)
        #expect(text.contains("status: revised") && text.contains("as_of: 2026-11-12"))
        try await claims.setStatus(.retired, of: path, now: now.addingTimeInterval(86_400 * 9))
        #expect(try read(temp, path).contains("as_of: 2026-11-12"), "retiring keeps the last as_of")
    }
}
