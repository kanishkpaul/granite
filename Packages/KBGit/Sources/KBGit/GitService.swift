import Foundation

public struct FileChange: Sendable, Hashable {
    public enum Kind: String, Sendable {
        case added, modified, deleted, renamed
    }

    public let kind: Kind
    public let path: String
}

/// Why auto-commit stopped: too many deletions, or notes that became empty.
/// Evicted iCloud files and runaway agents both look like this (research report 02).
public struct DeletionAlarm: Sendable, Equatable {
    public let deletions: [String]
    public let emptyNotes: [String]

    public var reason: String {
        var parts: [String] = []
        if !deletions.isEmpty { parts.append("\(deletions.count) files would be deleted") }
        if !emptyNotes.isEmpty { parts.append("\(emptyNotes.count) notes are empty (0 bytes)") }
        return parts.joined(separator: " and ")
    }
}

public enum CommitOutcome: Sendable, Equatable {
    case committed(sha: String, summary: String)
    case nothingToCommit
    /// The alarm fired; nothing was staged or committed.
    case paused(DeletionAlarm)
    /// Another git operation is running or unfinished (lock, merge, rebase…).
    case skipped(String)
    case notARepository
}

public enum PushOutcome: Sendable, Equatable {
    case pushed
    case noRemote
    case failed(String)
}

public struct RepositoryState: Sendable, Equatable {
    public let isRepository: Bool
    public let branch: String?
    public let remotes: [String]
    public let pending: [FileChange]
    public let busy: String?
}

/// granite's git safety net for a vault (master plan §10): periodic commits, a deletion alarm,
/// push to a private remote. Shells out to `/usr/bin/git`; never prompts, never force-pushes,
/// never runs `git init` unless asked.
public actor GitService {
    public static let deletionThreshold = 20
    public static let defaultIgnore = [".obsidian/workspace*.json", ".obsidian/cache", ".trash/", ".DS_Store"]

    public let root: URL
    let runner: GitRunner
    let deletionThreshold: Int

    public init(root: URL, git: URL = URL(filePath: "/usr/bin/git"), deletionThreshold: Int = GitService.deletionThreshold) {
        self.root = root
        self.runner = GitRunner(executable: git, directory: root)
        self.deletionThreshold = deletionThreshold
    }

    // MARK: State

    public func isRepository() async -> Bool {
        guard let output = try? await runner.run(["rev-parse", "--is-inside-work-tree"], check: false) else { return false }
        return output.succeeded && output.text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    public func state() async throws -> RepositoryState {
        guard await isRepository() else {
            return RepositoryState(isRepository: false, branch: nil, remotes: [], pending: [], busy: nil)
        }
        let branch = try await runner.run(["rev-parse", "--abbrev-ref", "HEAD"], check: false)
        let remotes = try await runner.run(["remote"]).text.split(separator: "\n").map(String.init)
        let staged = try await analyze()
        return RepositoryState(isRepository: true,
                               branch: branch.succeeded ? branch.text.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                               remotes: remotes, pending: staged, busy: try await busyReason())
    }

    func gitDirectory() async throws -> URL {
        let path = try await runner.run(["rev-parse", "--absolute-git-dir"]).text.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    /// A lock or an unfinished merge/rebase means a person or another tool is mid-operation.
    func busyReason() async throws -> String? {
        let gitDir = try await gitDirectory()
        let markers = [("index.lock", "another git process holds the index lock"), ("MERGE_HEAD", "a merge is in progress"),
                       ("rebase-merge", "a rebase is in progress"), ("rebase-apply", "a rebase is in progress"),
                       ("CHERRY_PICK_HEAD", "a cherry-pick is in progress"), ("REVERT_HEAD", "a revert is in progress")]
        for (name, reason) in markers where FileManager.default.fileExists(atPath: gitDir.appending(path: name).path(percentEncoded: false)) {
            return reason
        }
        return nil
    }

    /// What `git add -A` would stage, with rename detection, computed in a throwaway index so the
    /// real one is never touched by a commit that the alarm stops.
    func analyze() async throws -> [FileChange] {
        let gitDir = try await gitDirectory()
        let scratch = FileManager.default.temporaryDirectory.appending(path: "granite-index-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let realIndex = gitDir.appending(path: "index")
        if FileManager.default.fileExists(atPath: realIndex.path(percentEncoded: false)) {
            try FileManager.default.copyItem(at: realIndex, to: scratch)
        }
        let env = ["GIT_INDEX_FILE": scratch.path(percentEncoded: false)]
        try await runner.run(["add", "-A"], environment: env)
        let hasHead = try await runner.run(["rev-parse", "--verify", "-q", "HEAD"], check: false).succeeded
        let diff = hasHead
            ? try await runner.run(["diff", "--cached", "--name-status", "-z", "-M"], environment: env)
            // No commits yet: compare against the empty tree.
            : try await runner.run(["diff", "--cached", "--name-status", "-z", "-M", "4b825dc642cb6eb9a060e54bf8d69288fbee4904"],
                                   environment: env)
        return Self.parseNameStatus(diff.stdout)
    }

    /// `--name-status -z`: "M\0path\0", "R100\0old\0new\0".
    static func parseNameStatus(_ data: Data) -> [FileChange] {
        let fields = data.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        var changes: [FileChange] = []
        var index = 0
        while index < fields.count {
            let code = fields[index]
            guard let letter = code.first else { index += 1; continue }
            switch letter {
            case "R", "C":
                guard index + 2 < fields.count else { return changes }
                changes.append(FileChange(kind: letter == "R" ? .renamed : .added, path: fields[index + 2]))
                index += 3
            default:
                guard index + 1 < fields.count else { return changes }
                let kind: FileChange.Kind = switch letter {
                case "A": .added
                case "D": .deleted
                default: .modified
                }
                changes.append(FileChange(kind: kind, path: fields[index + 1]))
                index += 2
            }
        }
        return changes
    }

    // MARK: Commit

    /// Stages everything and commits, unless the deletion alarm fires or git is busy.
    /// `allowAlarm` is the user's "Commit anyway" after reviewing.
    public func autoCommit(allowAlarm: Bool = false) async throws -> CommitOutcome {
        guard await isRepository() else { return .notARepository }
        if let busy = try await busyReason() { return .skipped(busy) }
        let changes = try await analyze()
        guard !changes.isEmpty else { return .nothingToCommit }

        let alarm = self.alarm(for: changes)
        if let alarm, !allowAlarm { return .paused(alarm) }

        try await runner.run(["add", "-A"])
        let summary = Self.summary(changes)
        try await runner.run(identityArguments() + ["commit", "-q", "--no-verify", "-m", summary])
        let sha = try await runner.run(["rev-parse", "--short", "HEAD"]).text.trimmingCharacters(in: .whitespacesAndNewlines)
        return .committed(sha: sha, summary: summary)
    }

    func alarm(for changes: [FileChange]) -> DeletionAlarm? {
        let deletions = changes.filter { $0.kind == .deleted }.map(\.path)
        let empty = changes.filter { $0.kind != .deleted && $0.path.lowercased().hasSuffix(".md") }.map(\.path).filter { path in
            let attributes = try? FileManager.default.attributesOfItem(atPath: root.appending(path: path).path(percentEncoded: false))
            return (attributes?[.size] as? NSNumber)?.intValue == 0
        }
        guard deletions.count > deletionThreshold || !empty.isEmpty else { return nil }
        return DeletionAlarm(deletions: deletions, emptyNotes: empty)
    }

    static func summary(_ changes: [FileChange]) -> String {
        let counts = Dictionary(grouping: changes, by: \.kind).mapValues(\.count)
        let parts = [FileChange.Kind.added, .modified, .deleted, .renamed].compactMap { kind -> String? in
            guard let count = counts[kind], count > 0 else { return nil }
            return "\(count) \(kind.rawValue)"
        }
        let noun = changes.count == 1 ? "file" : "files"
        return "auto: \(changes.count) \(noun) changed (\(parts.joined(separator: ", ")))"
    }

    /// Uses the repo's own identity; falls back to a granite identity only if none is configured.
    func identityArguments() async throws -> [String] {
        let email = try await runner.run(["config", "user.email"], check: false)
        guard !email.succeeded || email.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return ["-c", "user.name=granite", "-c", "user.email=granite@localhost"]
    }

    // MARK: Push and init

    /// Pushes the current branch. Never forces; sets the upstream on the first push.
    public func push() async throws -> PushOutcome {
        let remotes = try await runner.run(["remote"]).text.split(separator: "\n").map(String.init)
        guard let remote = remotes.first(where: { $0 == "origin" }) ?? remotes.first else { return .noRemote }
        let upstream = try await runner.run(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], check: false)
        let arguments = upstream.succeeded ? ["push", "-q"] : ["push", "-q", "-u", remote, "HEAD"]
        let result = try await runner.run(arguments, check: false)
        return result.succeeded ? .pushed : .failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Makes the vault a repository with the plan's `.gitignore` and a first commit. Only on request.
    public func initialize() async throws -> CommitOutcome {
        if !(await isRepository()) { try await runner.run(["init", "-q", "-b", "main"]) }
        let ignore = root.appending(path: ".gitignore")
        let existing = (try? String(contentsOf: ignore, encoding: .utf8)) ?? ""
        let missing = Self.defaultIgnore.filter { !existing.split(separator: "\n").map(String.init).contains($0) }
        if !missing.isEmpty {
            let prefix = existing.isEmpty || existing.hasSuffix("\n") ? existing : existing + "\n"
            try Data((prefix + missing.joined(separator: "\n") + "\n").utf8).write(to: ignore, options: .atomic)
        }
        return try await autoCommit()
    }
}
