import Foundation
import KBAI
import KBCore

/// Nightly jobs at 3 a.m. while granite runs (it stays in the menu bar): the digest and lint,
/// then link suggestions. A missed night is caught up once, a few minutes after launch.
extension VaultStore {
    static let digestHour = 3

    var digestLastRunKey: String { "granite.digest.lastRun." + (vault?.root.path(percentEncoded: false) ?? "") }

    var lastDigestRun: Date? {
        UserDefaults.standard.object(forKey: digestLastRunKey) as? Date
    }

    /// The most recent 3 a.m. at or before `now`.
    static func lastSlot(before now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: digestHour, minute: 0, second: 0, of: now) ?? now
        return today <= now ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    func scheduleNightly() {
        nightlyTask?.cancel()
        nightlyTask = Task {
            // Catch up a missed night once things have settled after launch.
            try? await Task.sleep(for: .seconds(180))
            while !Task.isCancelled {
                let now = Date()
                let slot = Self.lastSlot(before: now)
                if (lastDigestRun ?? .distantPast) < slot {
                    await runDigest(openAfter: false)
                }
                let next = Calendar.current.date(byAdding: .day, value: 1, to: Self.lastSlot(before: Date())) ?? now.addingTimeInterval(86_400)
                try? await Task.sleep(for: .seconds(max(60, next.timeIntervalSinceNow)))
            }
        }
    }

    /// Writes today's digest (⌘K "Run digest now" or the nightly job) and, at night, suggests links.
    func runDigest(openAfter: Bool = true) async {
        guard let indexer, let writer else { return }
        let since = lastDigestRun ?? Date().addingTimeInterval(-86_400)
        status = "Writing the digest…"
        do {
            let result = try await DigestJob(models: models, indexer: indexer, writer: writer).run(since: since)
            UserDefaults.standard.set(Date(), forKey: digestLastRunKey)
            status = "Digest: \(result.changed) changed note(s), \(result.lintIssues) lint issue(s)"
                + (result.touches > 0 ? ", \(result.touches) source(s) touching claims" : "")
            refreshLists()
            if openAfter { openNote(result.path) } else { await suggestLinks() }
        } catch {
            status = "Digest failed: \(error)"
        }
    }

    /// The newest digest file, for ⌘K "Open latest digest".
    func latestDigest() -> String? {
        guard let vault else { return nil }
        let folder = vault.url(for: DigestJob.folder)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasSuffix(".md") }.max().map { "\(DigestJob.folder)/\($0)" }
    }
}
