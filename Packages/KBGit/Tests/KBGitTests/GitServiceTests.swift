import Foundation
import Testing
@testable import KBGit

/// A throwaway vault repository with its own identity, so tests never depend on global git config.
final class Repo: @unchecked Sendable {
    let root: URL
    let base: URL

    init(initialize: Bool = true) async throws {
        base = FileManager.default.temporaryDirectory.appending(path: "granite-git-\(UUID().uuidString)")
        root = base.appending(path: "vault")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if initialize {
            try await git("init", "-q", "-b", "main")
            try await git("config", "user.name", "Test")
            try await git("config", "user.email", "test@example.com")
        }
    }

    var service: GitService { GitService(root: root) }

    @discardableResult
    func git(_ arguments: String...) async throws -> String {
        try await GitRunner(executable: URL(filePath: "/usr/bin/git"), directory: root).run(arguments).text
    }

    func put(_ path: String, _ text: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func remove(_ path: String) throws { try FileManager.default.removeItem(at: root.appending(path: path)) }

    func commitCount() async throws -> Int {
        Int(try await git("rev-list", "--count", "HEAD").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func stagedNames() async throws -> String { try await git("diff", "--cached", "--name-only") }
}

@Suite struct GitServiceTests {
    @Test func linesAddedPerMarkdownFile() async throws {
        let repo = try await Repo()
        try repo.put("Notes/a.md", "one\ntwo\n")
        try repo.put("image.png", "binary-ish")
        _ = try await repo.service.autoCommit()
        try repo.put("Notes/a.md", "one\ntwo\nthree\n")
        try repo.put("AI/Digests/d.md", "x\n")
        _ = try await repo.service.autoCommit()
        let added = try await repo.service.linesAdded(since: Date().addingTimeInterval(-3600))
        #expect(added == ["Notes/a.md": 3, "AI/Digests/d.md": 1])
        #expect(try await Repo(initialize: false).service.linesAdded(since: .distantPast).isEmpty)
    }

    @Test func notARepository() async throws {
        let repo = try await Repo(initialize: false)
        #expect(try await repo.service.autoCommit() == .notARepository)
        #expect(try await repo.service.state().isRepository == false)
    }

    @Test func initializeWritesIgnoreAndFirstCommit() async throws {
        let repo = try await Repo(initialize: false)
        try repo.put("Notes/a.md", "alpha\n")
        try repo.put(".obsidian/workspace.json", "{}")
        try repo.put(".DS_Store", "x")
        guard case .committed(_, let summary) = try await repo.service.initialize() else {
            Issue.record("expected a first commit")
            return
        }
        #expect(summary == "auto: 2 files changed (2 added)")  // the note and .gitignore
        let tracked = try await repo.git("ls-files")
        #expect(tracked.contains("Notes/a.md") && tracked.contains(".gitignore"))
        #expect(!tracked.contains("workspace.json") && !tracked.contains(".DS_Store"))
    }

    @Test func commitsWithSummaryThenNothing() async throws {
        let repo = try await Repo()
        try repo.put("Notes/a.md", "alpha\n")
        try repo.put("Notes/b.md", "bravo\n")
        _ = try await repo.service.autoCommit()
        try repo.put("Notes/a.md", "alpha edited\n")
        try repo.put("Notes/c.md", "charlie\n")
        try repo.remove("Notes/b.md")
        try FileManager.default.moveItem(at: repo.root.appending(path: "Notes/c.md"), to: repo.root.appending(path: "Notes/c2.md"))
        let outcome = try await repo.service.autoCommit()
        guard case .committed(let sha, let summary) = outcome else {
            Issue.record("expected commit, got \(outcome)")
            return
        }
        #expect(!sha.isEmpty)
        #expect(summary == "auto: 3 files changed (1 added, 1 modified, 1 deleted)")
        #expect(try await repo.service.autoCommit() == .nothingToCommit)
        #expect(try await repo.commitCount() == 2)
    }

    @Test func renamesAreNotDeletions() async throws {
        let repo = try await Repo()
        for index in 0..<30 { try repo.put("Notes/n\(index).md", "note number \(index) with enough text to match\n") }
        _ = try await repo.service.autoCommit()
        try FileManager.default.moveItem(at: repo.root.appending(path: "Notes"), to: repo.root.appending(path: "Archive"))
        guard case .committed(_, let summary) = try await repo.service.autoCommit() else {
            Issue.record("a folder rename must not trip the deletion alarm")
            return
        }
        #expect(summary == "auto: 30 files changed (30 renamed)")
    }

    @Test func massDeletionPausesAndLeavesIndexUntouched() async throws {
        let repo = try await Repo()
        for index in 0..<25 { try repo.put("Notes/n\(index).md", "note \(index)\n") }
        _ = try await repo.service.autoCommit()
        for index in 0..<21 { try repo.remove("Notes/n\(index).md") }
        try repo.put("Notes/new.md", "new\n")
        let outcome = try await repo.service.autoCommit()
        guard case .paused(let alarm) = outcome else {
            Issue.record("expected the alarm, got \(outcome)")
            return
        }
        #expect(alarm.deletions.count == 21)
        #expect(alarm.reason == "21 files would be deleted")
        #expect(try await repo.stagedNames().isEmpty, "the alarm must not stage anything")
        #expect(try await repo.commitCount() == 1)

        guard case .committed = try await repo.service.autoCommit(allowAlarm: true) else {
            Issue.record("commit anyway should commit")
            return
        }
        #expect(try await repo.commitCount() == 2)
    }

    @Test func twentyDeletionsAreFine() async throws {
        let repo = try await Repo()
        for index in 0..<20 { try repo.put("Notes/n\(index).md", "note \(index)\n") }
        _ = try await repo.service.autoCommit()
        for index in 0..<20 { try repo.remove("Notes/n\(index).md") }
        guard case .committed = try await repo.service.autoCommit() else {
            Issue.record("exactly 20 deletions is under the threshold")
            return
        }
    }

    @Test func emptyNotePausesEvenAlone() async throws {
        let repo = try await Repo()
        try repo.put("Notes/a.md", "content\n")
        _ = try await repo.service.autoCommit()
        try repo.put("Notes/a.md", "")
        guard case .paused(let alarm) = try await repo.service.autoCommit() else {
            Issue.record("a note truncated to 0 bytes must raise the alarm")
            return
        }
        #expect(alarm.emptyNotes == ["Notes/a.md"] && alarm.deletions.isEmpty)
    }

    @Test func userStagedWorkSurvivesAnAlarm() async throws {
        let repo = try await Repo()
        try repo.put("Notes/a.md", "a\n")
        _ = try await repo.service.autoCommit()
        try repo.put("Notes/staged.md", "staged by hand\n")
        try await repo.git("add", "Notes/staged.md")
        try repo.put("Notes/a.md", "")
        guard case .paused = try await repo.service.autoCommit() else {
            Issue.record("expected alarm")
            return
        }
        #expect(try await repo.stagedNames().trimmingCharacters(in: .whitespacesAndNewlines) == "Notes/staged.md")
    }

    @Test func skipsWhileGitIsBusy() async throws {
        let repo = try await Repo()
        try repo.put("Notes/a.md", "a\n")
        let gitDir = repo.root.appending(path: ".git")
        try Data().write(to: gitDir.appending(path: "index.lock"))
        #expect(try await repo.service.autoCommit() == .skipped("another git process holds the index lock"))
        try FileManager.default.removeItem(at: gitDir.appending(path: "index.lock"))
        try Data("abc\n".utf8).write(to: gitDir.appending(path: "MERGE_HEAD"))
        #expect(try await repo.service.autoCommit() == .skipped("a merge is in progress"))
    }

    @Test func separateGitDirectory() async throws {
        let repo = try await Repo(initialize: false)
        let external = repo.base.appending(path: "Vault.git")
        try await repo.git("init", "-q", "-b", "main", "--separate-git-dir", external.path(percentEncoded: false))
        try await repo.git("config", "user.email", "test@example.com")
        try await repo.git("config", "user.name", "Test")
        try repo.put("Notes/a.md", "a\n")
        guard case .committed = try await repo.service.autoCommit() else {
            Issue.record("separate git dir should work")
            return
        }
        try Data().write(to: external.appending(path: "index.lock"))
        guard case .skipped = try await repo.service.autoCommit() else {
            Issue.record("the lock lives in the separate git dir")
            return
        }
    }

    @Test func pushToRemote() async throws {
        let repo = try await Repo()
        #expect(try await repo.service.push() == .noRemote)
        let bare = repo.base.appending(path: "remote.git")
        _ = try await GitRunner(executable: URL(filePath: "/usr/bin/git"), directory: repo.base)
            .run(["init", "-q", "--bare", bare.path(percentEncoded: false)])
        try await repo.git("remote", "add", "origin", bare.path(percentEncoded: false))
        try repo.put("Notes/a.md", "a\n")
        _ = try await repo.service.autoCommit()
        #expect(try await repo.service.push() == .pushed)
        try repo.put("Notes/b.md", "b\n")
        _ = try await repo.service.autoCommit()
        #expect(try await repo.service.push() == .pushed, "second push uses the upstream set by the first")
        let remoteCount = try await GitRunner(executable: URL(filePath: "/usr/bin/git"), directory: bare)
            .run(["rev-list", "--count", "main"]).text.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(remoteCount == "2")
    }

    @Test func pushFailureIsReportedNotThrown() async throws {
        let repo = try await Repo()
        try await repo.git("remote", "add", "origin", repo.base.appending(path: "missing.git").path(percentEncoded: false))
        try repo.put("Notes/a.md", "a\n")
        _ = try await repo.service.autoCommit()
        guard case .failed(let message) = try await repo.service.push() else {
            Issue.record("expected a reported failure")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func parsesNameStatus() {
        let raw = Data("M\0a.md\0R087\0old.md\0new.md\0D\0gone.md\0A\0added.md\0".utf8)
        #expect(GitService.parseNameStatus(raw) == [
            FileChange(kind: .modified, path: "a.md"), FileChange(kind: .renamed, path: "new.md"),
            FileChange(kind: .deleted, path: "gone.md"), FileChange(kind: .added, path: "added.md"),
        ])
    }
}
