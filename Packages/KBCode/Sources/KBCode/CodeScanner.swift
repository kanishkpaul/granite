import CryptoKit
import Foundation
import KBCore
import KBGit

/// A code repository granite follows. Listed in `.granite/repos.json` (versioned with the vault).
public struct RepoConfig: Sendable, Codable, Equatable, Identifiable {
    public var name: String
    /// Absolute path, or "~/…".
    public var path: String
    public var id: String { name }

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }

    public var url: URL { URL(filePath: (path as NSString).expandingTildeInPath) }
}

public enum RepoRegistry {
    public static let path = ".granite/repos.json"

    public static func load(_ vault: Vault) -> [RepoConfig] {
        guard let data = try? Data(contentsOf: vault.url(for: path)) else { return [] }
        return (try? JSONDecoder().decode([RepoConfig].self, from: data)) ?? []
    }

    public static func save(_ repos: [RepoConfig], vault: Vault, writer: SafeWriter) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try await writer.write(try encoder.encode(repos), to: path, as: .user)
    }
}

/// A commit that reads like a design decision and has no decision record yet.
public struct DecisionCandidate: Sendable, Equatable {
    public let repo: String
    public let commit: Commit
}

public struct CodeScanReport: Sendable, Equatable {
    public var repo: String
    public var hub: String
    /// Imported or refreshed ADRs and agent memory files.
    public var sources: [String] = []
    /// Decision notes whose `commits` gained a sha from a `Granite-Decision:` trailer.
    public var linked: [String] = []
    public var candidates: [DecisionCandidate] = []
    public var unknownTrailers: [String] = []
}

/// Code-decision records (master plan §7, idea 8): a hub note per repo, the repo's ADRs and agent
/// memory files (CLAUDE.md, AGENTS.md) imported as source references, `Granite-Decision: <id>`
/// commit trailers linked to decision notes, and decision-like commits offered as stubs.
public actor CodeScanner {
    public static let trailer = "Granite-Decision"
    static let sourceFolders = ["docs/adr", "doc/adr", "adr", "docs/decisions", "decisions", "docs/architecture/decisions"]
    static let memoryFiles = ["CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md", "GEMINI.md"]

    let vault: Vault
    let writer: SafeWriter
    let git: URL
    /// Finds a decision note by frontmatter id or title; the app answers from the index.
    let resolve: @Sendable (String) -> String?

    public init(vault: Vault, writer: SafeWriter, git: URL = URL(filePath: "/usr/bin/git"),
                resolve: @escaping @Sendable (String) -> String?) {
        self.vault = vault
        self.writer = writer
        self.git = git
        self.resolve = resolve
    }

    public static func folder(for repo: String) -> String { "Code/\(NoteFileNameKB.make(repo))" }

    public func scan(_ repo: RepoConfig, now: Date = Date()) async throws -> CodeScanReport {
        let service = GitService(root: repo.url, git: git)
        let folder = Self.folder(for: repo.name)
        var report = CodeScanReport(repo: repo.name, hub: "\(folder).md")

        for (relative, kind) in Self.sourceFiles(in: repo.url) {
            if let path = try await importSource(relative, kind: kind, repo: repo, folder: folder) { report.sources.append(path) }
        }

        let commits = try await service.commits(limit: 300)
        var linkedShas = Set<String>()
        for commit in commits {
            for reference in commit.trailers(Self.trailer) {
                guard let path = resolve(reference) else {
                    report.unknownTrailers.append("\(commit.sha.prefix(8)): \(reference)")
                    continue
                }
                linkedShas.insert(commit.sha)
                if try await addCommit(commit.sha, repo: repo.name, to: path) { report.linked.append(path) }
            }
        }
        report.candidates = commits.prefix(100).filter { !linkedShas.contains($0.sha) && Self.looksLikeDecision($0) }
            .prefix(10).map { DecisionCandidate(repo: repo.name, commit: $0) }

        try await writeHub(repo, folder: folder, commits: Array(commits.prefix(10)), report: report,
                           remote: await service.remoteURL(), branch: await service.currentBranch(), now: now)
        return report
    }

    // MARK: Sources

    static func sourceFiles(in root: URL) -> [(String, String)] {
        var files: [(String, String)] = []
        let manager = FileManager.default
        for folder in sourceFolders {
            let url = root.appending(path: folder)
            let names = (try? manager.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
            for name in names.sorted() where name.lowercased().hasSuffix(".md") && name.lowercased() != "readme.md" {
                files.append(("\(folder)/\(name)", "adr"))
            }
        }
        for name in memoryFiles where manager.fileExists(atPath: root.appending(path: name).path(percentEncoded: false)) {
            files.append((name, "agent-memory"))
        }
        return files
    }

    static let begin = "<!-- granite:code:begin (copied from the repository; replaced when the file changes) -->"
    static let end = "<!-- granite:code:end -->"

    /// Copies a repository file into the vault as a source reference; skipped when unchanged.
    func importSource(_ relative: String, kind: String, repo: RepoConfig, folder: String) async throws -> String? {
        let url = repo.url.appending(path: relative)
        guard let data = try? Data(contentsOf: url), data.count < 1_000_000 else { return nil }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(16)
        let name = relative.replacingOccurrences(of: "/", with: " – ")
        let path = "\(folder)/sources/\(NoteFileNameKB.make(String(name.dropLast(3)))).md"
        let existing = try? String(contentsOf: vault.url(for: path), encoding: .utf8)
        if let existing, MarkdownDocument(text: existing).frontmatter?["sha"]?.text == String(hash) { return nil }
        let content = String(decoding: data, as: UTF8.self)
        let region = [Self.begin, content.trimmingCharacters(in: .whitespacesAndNewlines), Self.end].joined(separator: "\n")
        let text: String
        if let existing, let start = existing.range(of: Self.begin), let finish = existing.range(of: Self.end, range: start.upperBound..<existing.endIndex) {
            text = try FrontmatterEditor.setScalar("sha", to: String(hash),
                                                   in: existing.replacingCharacters(in: start.lowerBound..<finish.upperBound, with: region))
        } else {
            text = ["---", "type: source", "kind: \(kind)", "origin: source", "repo: \"[[\(folder)]]\"",
                    "file: \(FrontmatterEditor.yamlScalar(relative))", "sha: \(hash)", "---",
                    "From `\(repo.name)/\(relative)`. Your notes go above or below the copied text.", "", region, ""].joined(separator: "\n")
        }
        try await writer.write(text, to: path, as: .user)
        return path
    }

    // MARK: Trailers

    /// Adds `sha` to a decision note's `commits` list (and `repo`); false if already there.
    func addCommit(_ sha: String, repo: String, to path: String) async throws -> Bool {
        let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        let frontmatter = MarkdownDocument(text: text).frontmatter
        var commits = frontmatter?["commits"]?.strings ?? []
        guard !commits.contains(where: { sha.hasPrefix($0) || $0.hasPrefix(sha) }) else { return false }
        commits.append(sha)
        var updated = try FrontmatterEditor.setRaw("commits", yaml: FrontmatterEditor.yamlList(commits), in: text)
        if frontmatter?["repo"] == nil { updated = try FrontmatterEditor.setScalar("repo", to: "[[\(Self.folder(for: repo))]]", in: updated) }
        try await writer.write(updated, to: path, as: .user)
        return true
    }

    // MARK: Candidates

    static let decisionPhrases = ["switch to", "switched to", "switch from", "replace", "replaced", "migrate", "migrated",
                                  "adopt", "adopted", "instead of", "drop", "dropped", "deprecate", "deprecated", "decided to",
                                  "choose", "chose", "move to", "moved to", "rewrite", "rewrote", "remove support", "stop using",
                                  "in favour of", "in favor of"]

    /// Heuristic: subjects that change direction ("switch to GRDB", "drop Combine"), not fixes or tidying.
    public static func looksLikeDecision(_ commit: Commit) -> Bool {
        let subject = commit.subject.lowercased()
        if subject.hasPrefix("merge ") || subject.hasPrefix("revert") || subject.hasPrefix("fix") || subject.hasPrefix("bump") { return false }
        return decisionPhrases.contains { phrase in
            subject.range(of: "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b", options: .regularExpression) != nil
        }
    }

    /// The proposal for a decision stub: you write the why.
    public static func stub(for candidate: DecisionCandidate, title: String? = nil, date: String) -> Proposal {
        let name = title ?? candidate.commit.subject
        let path = "\(folder(for: candidate.repo))/\(NoteFileNameKB.make(String(name.prefix(80)))).md"
        let lines = ["---", "type: decision", "domain: code", "status: proposed", "repo: \"[[\(folder(for: candidate.repo))]]\"",
                     "commits: [\"\(candidate.commit.sha)\"]", "created: \(date)", "---", "# \(name)", "",
                     "## Context", candidate.commit.subject + (candidate.commit.body.isEmpty ? "" : "\n\n" + candidate.commit.body), "",
                     "## Decision", "", "## Why", "(your words: what you weighed, what you gave up)", "",
                     "Commit trailer for follow-ups: `\(trailer): \(name)`"]
        return Proposal(kind: .decision, target: path, feature: "code-decisions", model: title == nil ? "none" : "on-device",
                        rationale: "Commit \(candidate.commit.sha.prefix(8)) in \(candidate.repo) reads like a design decision; record why.",
                        change: ProposalChange(added: lines), citations: [], created: date)
    }

    // MARK: Hub

    static let hubBegin = "<!-- granite:repo:begin (refreshed on every scan) -->"
    static let hubEnd = "<!-- granite:repo:end -->"

    func writeHub(_ repo: RepoConfig, folder: String, commits: [Commit], report: CodeScanReport, remote: String?, branch: String?,
                  now: Date) async throws {
        let path = "\(folder).md"
        var region = [Self.hubBegin, "## Repository", "- Path: `\(repo.path)`"]
        if let remote { region.append("- Remote: \(remote)") }
        if let branch { region.append("- Branch: \(branch)") }
        region.append("- Scanned: \(ISO8601DateFormatter().string(from: now))")
        let sources = (try? FileManager.default.contentsOfDirectory(atPath: vault.url(for: "\(folder)/sources").path(percentEncoded: false))) ?? []
        if !sources.isEmpty {
            region += ["", "## Sources (ADRs, agent memory)"]
            region += sources.sorted().filter { $0.hasSuffix(".md") }.map { "- [[\(folder)/sources/\(String($0.dropLast(3)))|\(String($0.dropLast(3)))]]" }
        }
        if !commits.isEmpty {
            region += ["", "## Recent commits"]
            region += commits.map { "- `\($0.sha.prefix(8))` \($0.subject)" }
        }
        region.append(Self.hubEnd)
        let block = region.joined(separator: "\n")
        let existing = try? String(contentsOf: vault.url(for: path), encoding: .utf8)
        let text: String
        if let existing, let start = existing.range(of: Self.hubBegin), let finish = existing.range(of: Self.hubEnd, range: start.upperBound..<existing.endIndex) {
            text = existing.replacingCharacters(in: start.lowerBound..<finish.upperBound, with: block)
        } else if let existing {
            text = existing + (existing.hasSuffix("\n") ? "\n" : "\n\n") + block + "\n"
        } else {
            text = ["---", "type: project", "kind: repo", "origin: human", "repo: \(FrontmatterEditor.yamlScalar(repo.path))", "---",
                    "# \(repo.name)", "", "What this repository is for, in your words.", "", block, ""].joined(separator: "\n")
        }
        try await writer.write(text, to: path, as: .user)
    }
}

/// File names for notes granite creates (same rules as `KBIndex.NoteFileName`; KBCode doesn't depend on KBIndex).
enum NoteFileNameKB {
    static func make(_ title: String) -> String {
        let forbidden = Set("/\\:*?\"<>|#^[]")
        var cleaned = String(title.map { forbidden.contains($0) || $0.isNewline ? " " : $0 })
        while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = String(cleaned.prefix(120)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
