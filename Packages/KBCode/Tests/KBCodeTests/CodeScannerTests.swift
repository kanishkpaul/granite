import Foundation
import KBCore
import KBGit
import Testing
@testable import KBCode

@Suite struct CodeScannerTests {
    func git(_ root: URL, _ arguments: String...) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "git \(arguments)")
    }

    func setUp() async throws -> (Vault, RepoConfig, URL) {
        let base = FileManager.default.temporaryDirectory.appending(path: "granite-code-\(UUID().uuidString)")
        let vaultRoot = base.appending(path: "vault")
        let repo = base.appending(path: "repo")
        for folder in [vaultRoot.appending(path: "Code/app"), repo.appending(path: "docs/adr")] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try Data("# 1. Use SQLite\nWe chose SQLite.\n".utf8).write(to: repo.appending(path: "docs/adr/0001-use-sqlite.md"))
        try Data("# Agent rules\nRun tests.\n".utf8).write(to: repo.appending(path: "CLAUDE.md"))
        try Data("""
            ---
            id: 01JC9Q7Z5W3K8M2R4T6V8X0Y1A
            type: decision
            domain: code
            ---
            Use GRDB.
            """.utf8).write(to: vaultRoot.appending(path: "Code/app/Use GRDB.md"))
        try await git(repo, "init", "-q", "-b", "main")
        try await git(repo, "config", "user.name", "T")
        try await git(repo, "config", "user.email", "t@example.com")
        try await git(repo, "add", "-A")
        try await git(repo, "commit", "-q", "-m", "Switch to GRDB for the index\n\nGranite-Decision: 01JC9Q7Z5W3K8M2R4T6V8X0Y1A")
        try Data("x".utf8).write(to: repo.appending(path: "a.txt"))
        try await git(repo, "add", "-A")
        try await git(repo, "commit", "-q", "-m", "Drop Combine in favour of async/await")
        try Data("y".utf8).write(to: repo.appending(path: "b.txt"))
        try await git(repo, "add", "-A")
        try await git(repo, "commit", "-q", "-m", "Fix typo\n\nGranite-Decision: Missing decision")
        return (Vault(root: vaultRoot), RepoConfig(name: "app", path: repo.path(percentEncoded: false)), repo)
    }

    @Test func scanImportsLinksAndSuggests() async throws {
        let (vault, repo, repoURL) = try await setUp()
        let scanner = CodeScanner(vault: vault, writer: SafeWriter(vault: vault)) { reference in
            reference == "01JC9Q7Z5W3K8M2R4T6V8X0Y1A" ? "Code/app/Use GRDB.md" : nil
        }
        let report = try await scanner.scan(repo)
        #expect(report.hub == "Code/app.md")
        #expect(report.sources.sorted() == ["Code/app/sources/CLAUDE.md", "Code/app/sources/docs – adr – 0001-use-sqlite.md"])
        #expect(report.linked == ["Code/app/Use GRDB.md"])
        #expect(report.unknownTrailers.count == 1 && report.unknownTrailers[0].hasSuffix("Missing decision"))
        #expect(report.candidates.map(\.commit.subject) == ["Drop Combine in favour of async/await"])

        let decision = try String(contentsOf: vault.url(for: "Code/app/Use GRDB.md"), encoding: .utf8)
        #expect(decision.range(of: #"commits: \["[0-9a-f]{40}"\]"#, options: .regularExpression) != nil)
        #expect(decision.contains("repo: \"[[Code/app]]\""))
        let adr = try String(contentsOf: vault.url(for: "Code/app/sources/docs – adr – 0001-use-sqlite.md"), encoding: .utf8)
        #expect(adr.contains("kind: adr") && adr.contains("We chose SQLite."))
        let hub = try String(contentsOf: vault.url(for: "Code/app.md"), encoding: .utf8)
        #expect(hub.contains("type: project") && hub.contains("Drop Combine in favour of async/await") && hub.contains("[[Code/app/sources/CLAUDE|CLAUDE]]"))

        // A second scan changes nothing it already did, keeps your hub text, refreshes a changed ADR.
        try Data(hub.replacingOccurrences(of: "What this repository is for, in your words.", with: "My app.").utf8)
            .write(to: vault.url(for: "Code/app.md"))
        try Data("# 1. Use SQLite\nWe chose SQLite. Still true.\n".utf8).write(to: repoURL.appending(path: "docs/adr/0001-use-sqlite.md"))
        let again = try await scanner.scan(repo)
        #expect(again.linked.isEmpty && again.sources == ["Code/app/sources/docs – adr – 0001-use-sqlite.md"])
        #expect(try String(contentsOf: vault.url(for: "Code/app.md"), encoding: .utf8).contains("My app."))
        #expect(try String(contentsOf: vault.url(for: again.sources[0]), encoding: .utf8).contains("Still true."))
    }

    @Test func decisionStubsAreProposals() throws {
        let commit = Commit(sha: String(repeating: "a", count: 40), date: Date(), subject: "Switch to GRDB", body: "FTS5 is built in.")
        let proposal = CodeScanner.stub(for: DecisionCandidate(repo: "app", commit: commit), date: "2026-11-09")
        #expect(proposal.kind == .decision && proposal.createsNote && proposal.target == "Code/app/Switch to GRDB.md")
        guard case .create(let path, let text) = try ProposalApplier.apply(proposal, to: nil) else {
            Issue.record("expected a new note")
            return
        }
        #expect(path == "Code/app/Switch to GRDB.md")
        let note = NoteParser.parse(data: Data(text.utf8), path: path, policy: .builtIn)
        #expect(note.type == .decision && text.contains("FTS5 is built in.") && text.contains("## Why"))
        #expect(!CodeScanner.looksLikeDecision(Commit(sha: "", date: Date(), subject: "Fix crash when switching to dark mode", body: "")))
        #expect(CodeScanner.looksLikeDecision(Commit(sha: "", date: Date(), subject: "Migrate settings to SwiftData", body: "")))
        #expect(!CodeScanner.looksLikeDecision(Commit(sha: "", date: Date(), subject: "Inbox decide queue, rename and move", body: "")))
        #expect(!CodeScanner.looksLikeDecision(Commit(sha: "", date: Date(), subject: "Add dropdown menu", body: "")))
    }

    @Test func registryRoundTrips() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "granite-repos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let vault = Vault(root: root)
        let repos = [RepoConfig(name: "granite", path: "~/Downloads/GitHub/granite")]
        try await RepoRegistry.save(repos, vault: vault, writer: SafeWriter(vault: vault))
        #expect(RepoRegistry.load(vault) == repos)
        #expect(repos[0].url.path(percentEncoded: false).hasPrefix("/Users/"))
    }
}
