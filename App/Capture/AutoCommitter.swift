import AppKit
import KBGit
import UserNotifications

/// Commits the vault 5 minutes after the last change and on quit, pushes if there is a remote,
/// and stops with an alarm when a commit looks like data loss (master plan §10).
@MainActor
@Observable
final class AutoCommitter {
    enum State: Equatable {
        case off(String)
        case idle(String)
        case waiting
        case working
        case paused(DeletionAlarm)
        case failed(String)
    }

    static let enabledKey = "granite.autoCommit"
    private(set) var state = State.off("No vault open.")
    private(set) var isRepository = false
    private var service: GitService?
    private var timer: Task<Void, Never>?
    private var dirty = false

    /// 5 minutes; `GRANITE_AUTOCOMMIT_DELAY` (seconds) overrides it for testing.
    let delay: Duration = .seconds(Int(ProcessInfo.processInfo.environment["GRANITE_AUTOCOMMIT_DELAY"] ?? "") ?? 300)

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            Task { await refresh() }
        }
    }

    var statusText: String {
        switch state {
        case .off(let reason): "Auto-commit off: \(reason)"
        case .idle(let last): last
        case .waiting: "Changes pending; committing after 5 minutes of quiet."
        case .working: "Committing…"
        case .paused(let alarm): "Auto-commit paused: \(alarm.reason)."
        case .failed(let message): "Git: \(message)"
        }
    }

    func configure(root: URL) async {
        timer?.cancel()
        service = GitService(root: root)
        await refresh()
    }

    func refresh() async {
        guard let service else { return }
        isRepository = await service.isRepository()
        if !isRepository {
            state = .off("the vault is not a git repository (Settings → Initialize git).")
        } else if !isEnabled {
            state = .off("turned off in Settings.")
        } else if case .off = state {
            state = .idle("Auto-commit on.")
        }
    }

    /// Called for every vault change; restarts the quiet-period timer.
    func vaultChanged() {
        guard isRepository, isEnabled else { return }
        if case .paused = state { return }
        dirty = true
        state = .waiting
        timer?.cancel()
        timer = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await commit()
        }
    }

    /// Commits now. `allowAlarm` is the user's "Commit anyway" after reviewing.
    func commit(allowAlarm: Bool = false) async {
        guard let service, isRepository else { return }
        timer?.cancel()
        state = .working
        do {
            switch try await service.autoCommit(allowAlarm: allowAlarm) {
            case .committed(let sha, let summary):
                dirty = false
                state = .idle("Committed \(sha): \(summary)")
                switch try await service.push() {
                case .pushed: state = .idle("Committed and pushed \(sha): \(summary)")
                case .noRemote: break
                case .failed(let message): state = .failed("committed \(sha), push failed: \(message)")
                }
            case .nothingToCommit:
                dirty = false
                state = .idle("Nothing to commit.")
            case .paused(let alarm):
                state = .paused(alarm)
                notify(alarm)
            case .skipped(let reason):
                state = .idle("Skipped: \(reason).")
            case .notARepository:
                await refresh()
            }
        } catch {
            state = .failed("\(error)")
        }
    }

    /// Settings → Initialize git.
    func initialize() async {
        guard let service else { return }
        do {
            _ = try await service.initialize()
            await refresh()
            state = .idle("Initialized git and made the first commit.")
        } catch {
            state = .failed("\(error)")
        }
    }

    /// "Commit anyway…": confirm with the list of affected files first.
    func confirmCommitAnyway() {
        guard case .paused(let alarm) = state else { return }
        let alert = NSAlert()
        alert.messageText = "Commit anyway?"
        let listed = (alarm.deletions.prefix(12) + alarm.emptyNotes.prefix(6)).joined(separator: "\n")
        let more = alarm.deletions.count + alarm.emptyNotes.count > 18 ? "\n…" : ""
        alert.informativeText = "\(alarm.reason).\n\n\(listed)\(more)\n\nIf these changes are not intended, restore the files with git instead."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Commit Anyway")
        alert.addButton(withTitle: "Cancel")
        NSApplication.shared.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await commit(allowAlarm: true) }
    }

    /// On quit: commit pending changes, bounded so quitting never hangs.
    func commitBeforeQuit() async {
        guard dirty, isRepository, isEnabled else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.commit() }
            group.addTask { try? await Task.sleep(for: .seconds(10)) }
            await group.next()
            group.cancelAll()
        }
    }

    private func notify(_ alarm: DeletionAlarm) {
        let center = UNUserNotificationCenter.current()
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            content.title = "granite paused auto-commit"
            content.body = "\(alarm.reason). Check the vault, then use Commit Anyway in the menu bar if it's intended."
            try? await center.add(UNNotificationRequest(identifier: "granite.alarm", content: content, trigger: nil))
        }
    }
}
