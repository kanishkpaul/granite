import Foundation
import GRDB
import KBAI
import KBCore
import KBIndex

/// What the week left behind, for the weekly review.
struct WeekMaterial {
    var week: String
    var dailyNotes: [NoteRecord] = []
    var newClaims: [ClaimRecord] = []
    var inbox = 0
    var proposals = 0
    var changed = 0
}

/// The weekly Socratic review (master plan §7, idea 11): it asks first; "Challenge me" weighs
/// your answer against your own notes; only what you wrote is saved, to `Daily/YYYY-Www.md`.
extension VaultStore {
    func weekMaterial(now: Date = Date()) -> WeekMaterial {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 86_400)
        var material = WeekMaterial(week: WeeklyNote.week(of: now))
        guard let database else { return material }
        let recent = (try? database.recent(limit: 500, since: start)) ?? []
        material.dailyNotes = recent.filter { $0.path.hasPrefix("Daily/") && $0.type == "daily" && !$0.path.contains("-W") }
            .sorted { $0.path < $1.path }
        material.changed = recent.filter { !$0.path.hasPrefix("AI/") }.count
        let startDay = ClaimDay.string(start)
        material.newClaims = claims.filter { ($0.asOf ?? "") >= startDay && $0.status == .held }
        material.inbox = inboxItems.count
        material.proposals = openProposals.count
        return material
    }

    /// Counter-examples and support for your answer, from your notes only (Socratic mode, logged).
    func challenge(_ answer: String, question: String) async throws -> QAAnswer {
        guard let database, let models else { throw NoVaultError() }
        let reranker = semantic.isEnabled ? await semantic.loadReranker() : nil
        let searcher = semantic.searcher ?? HybridSearcher(database: database, vectors: nil, embedder: nil, reranker: reranker)
        let policy = self.policy
        // Search by what you wrote, not by the question: the counter-examples are about your view.
        let qa = GroundedQA(models: models, untrusted: { policy.policy(for: $0).trust == "untrusted" },
                            retrieve: { _ in
                                var options = HybridOptions()
                                options.limit = 8
                                options.useReranker = true
                                return try await searcher.search(answer, options: options)
                            })
        let result = try await qa.ask(question, mode: .socratic, userView: answer)
        try? state?.recordQA(route: result.route?.rawValue ?? "none", mode: "weekly-review", abstained: result.abstained,
                             sentences: result.sentences.count, verified: result.verifiedCount)
        return result
    }

    /// Saves your answers to this week's note (created or extended) and opens it.
    func saveWeeklyNote(_ answers: [(question: String, answer: String)], now: Date = Date()) async {
        guard let vault, let writer else { return }
        let week = WeeklyNote.week(of: now)
        let path = WeeklyNote.path(for: week)
        let existing = try? String(contentsOf: vault.url(for: path), encoding: .utf8)
        let text = WeeklyNote.render(week: week, answers: answers, existing: existing, date: ClaimDay.string(now))
        do {
            try await writer.write(text, to: path, as: .user)
            _ = try await indexer?.update(paths: [path])
            try? state?.record(feature: "weekly-review", action: .accepted, target: path)
            status = "Saved \(path)"
            refreshLists()
            openNote(path)
        } catch {
            status = "Could not save the weekly note: \(error)"
        }
    }

    /// True when this week's note doesn't exist yet (the sidebar nudges on weekends).
    var weeklyReviewDue: Bool {
        guard let vault else { return false }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let path = WeeklyNote.path(for: WeeklyNote.week(of: Date()))
        return (weekday == 1 || weekday == 7) && !FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false))
    }
}

enum ClaimDay {
    static func string(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
