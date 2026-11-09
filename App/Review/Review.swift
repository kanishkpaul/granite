import Foundation
import KBAI
import KBCore
import KBIndex
import KBReview

/// Spaced retrieval in the app: the due count, grading, and "Make prompts".
extension VaultStore {
    func refreshDue() async {
        guard let reviewQueue else { return }
        dueCount = (try? await reviewQueue.due().count) ?? 0
    }

    func duePrompts() async -> [DuePrompt] {
        (try? await reviewQueue?.due()) ?? []
    }

    /// Records a grade; returns the prompt's next state.
    func grade(_ prompt: Prompt, _ grade: Grade, seconds: Double) async -> CardState? {
        guard let reviewQueue else { return nil }
        do {
            return try await reviewQueue.grade(prompt, grade, seconds: seconds)
        } catch {
            status = "Could not save the review: \(error)"
            return nil
        }
    }

    func reviewStats() async -> ReviewStats? {
        try? await reviewQueue?.stats()
    }

    /// Previews of the next interval for each grade, for the buttons ("10m", "3d", "2w").
    func intervals(for card: CardState?) -> [Grade: String] {
        let fsrs = FSRS()
        let now = Date()
        return Dictionary(uniqueKeysWithValues: Grade.allCases.map { grade in
            let next = fsrs.review(card, grade: grade, now: now)
            return (grade, Self.shortInterval(next.due.timeIntervalSince(now)))
        })
    }

    static func shortInterval(_ seconds: TimeInterval) -> String {
        let days = seconds / 86_400
        if days < 1 { return "\(max(1, Int((seconds / 60).rounded())))m" }
        if days < 14 { return "\(Int(days.rounded()))d" }
        if days < 60 { return "\(Int((days / 7).rounded()))w" }
        if days < 365 { return "\(Int((days / 30).rounded()))mo" }
        return String(format: "%.1fy", days / 365)
    }

    /// ⌘K "Make prompts from this note": drafts 3–5 prompts as proposals.
    func makePrompts() async {
        guard let path = openPath, let vault, let models, let proposalStore, let database else { return }
        guard let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { return }
        let label = (try? database.note(path: path)).flatMap { $0.flatMap { AILabel(rawValue: $0.aiLabel) } } ?? .local
        status = "Drafting prompts…"
        do {
            let created = try await PromptDrafter(models: models, store: proposalStore).draft(path: path, text: text, label: label)
            status = created.isEmpty ? "No new prompts drafted." : "Drafted \(created.count) prompt(s): accept or edit them in Proposals."
            await refreshProposals()
            refreshLists()
        } catch {
            status = "Could not draft prompts: \(ModelError.brief(error))"
        }
    }
}
