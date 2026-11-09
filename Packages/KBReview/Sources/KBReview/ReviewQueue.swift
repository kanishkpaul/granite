import Foundation
import GRDB
import KBCore
import KBIndex

/// A prompt waiting for review, with its schedule.
public struct DuePrompt: Sendable, Equatable, Identifiable {
    public let prompt: Prompt
    /// nil for a prompt never reviewed.
    public let card: CardState?
    public var id: String { prompt.id }

    public init(prompt: Prompt, card: CardState?) {
        self.prompt = prompt
        self.card = card
    }
}

public struct ReviewStats: Sendable, Equatable {
    public let total: Int
    public let due: Int
    public let new: Int
    /// Share of reviews in the window graded hard, good or easy (the retention metric, §11).
    public let recall: Double?
    public let reviewed: Int
}

/// The daily review: due prompts first, then up to `newPerDay` new ones. Grading appends to
/// `.granite/reviews.jsonl`; a prompt without a block id gets one on its first review.
public actor ReviewQueue {
    public let indexer: Indexer
    let writer: SafeWriter
    let fsrs: FSRS
    public var newPerDay: Int

    public init(indexer: Indexer, writer: SafeWriter, fsrs: FSRS = FSRS(), newPerDay: Int = 10) {
        self.indexer = indexer
        self.writer = writer
        self.fsrs = fsrs
        self.newPerDay = newPerDay
    }

    var vault: Vault { indexer.vault }

    /// Every prompt in the vault (notes the index says hold a `[!prompt]` callout).
    public func prompts() async throws -> [Prompt] {
        let paths = try await indexer.database.pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT o.path FROM blocks b JOIN objects o ON o.rowid = b.obj
                WHERE b.kind = 'callout' AND b.text LIKE '%[!prompt]%' AND o.path NOT LIKE 'AI/%' ORDER BY o.path
                """)
        }
        return paths.flatMap { path -> [Prompt] in
            guard let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { return [] }
            return PromptParser.prompts(in: text, path: path)
        }
    }

    public func events() -> [ReviewEvent] {
        let text = (try? String(contentsOf: vault.url(for: ReviewLog.path), encoding: .utf8)) ?? ""
        return ReviewLog.events(in: text)
    }

    /// Due prompts (most overdue first), then new ones up to today's allowance.
    public func due(now: Date = Date(), calendar: Calendar = .current) async throws -> [DuePrompt] {
        let events = events()
        let cards = ReviewLog.replay(events, fsrs: fsrs)
        let all = try await prompts()
        let due = all.compactMap { prompt -> DuePrompt? in
            guard let key = prompt.key, let card = cards[key], card.due <= now else { return nil }
            return DuePrompt(prompt: prompt, card: card)
        }.sorted { ($0.card?.due ?? now) < ($1.card?.due ?? now) }
        let startOfDay = calendar.startOfDay(for: now)
        let seenToday = Set(events.filter { $0.ts >= startOfDay }.map(\.prompt))
        let firstReviews = Dictionary(events.map { ($0.prompt, $0.ts) }, uniquingKeysWith: min)
        let introducedToday = firstReviews.filter { $0.value >= startOfDay }.count
        let fresh = all.filter { prompt in prompt.key.map { cards[$0] == nil && !seenToday.contains($0) } ?? true }
            .prefix(max(0, newPerDay - introducedToday))
            .map { DuePrompt(prompt: $0, card: nil) }
        return due + fresh
    }

    /// Records a grade. Returns the prompt's next state.
    @discardableResult
    public func grade(_ prompt: Prompt, _ grade: Grade, seconds: Double? = nil, now: Date = Date()) async throws -> CardState {
        var key = prompt.key
        if key == nil {
            key = try await assignBlockID(prompt)
        }
        guard let key else { throw ReviewError.cannotIdentify(prompt.path) }
        let cards = ReviewLog.replay(events(), fsrs: fsrs)
        let next = fsrs.review(cards[key], grade: grade, now: now)
        var log = (try? String(contentsOf: vault.url(for: ReviewLog.path), encoding: .utf8)) ?? ""
        if !log.isEmpty && !log.hasSuffix("\n") { log += "\n" }
        log += ReviewLog.line(ReviewEvent(ts: now, prompt: key, grade: grade, seconds: seconds)) + "\n"
        try await writer.write(log, to: ReviewLog.path, as: .user)
        return next
    }

    /// Counts for the review screen and the weekly metrics.
    public func stats(now: Date = Date(), window: TimeInterval = 7 * 86_400) async throws -> ReviewStats {
        let events = events()
        let cards = ReviewLog.replay(events, fsrs: fsrs)
        let all = try await prompts()
        let due = all.filter { prompt in prompt.key.flatMap { cards[$0] }.map { $0.due <= now } ?? false }.count
        let new = all.filter { prompt in prompt.key.map { cards[$0] == nil } ?? true }.count
        let recent = events.filter { $0.ts >= now.addingTimeInterval(-window) }
        let recalled = recent.filter { $0.grade > Grade.again.rawValue }.count
        return ReviewStats(total: all.count, due: due, new: new,
                           recall: recent.isEmpty ? nil : Double(recalled) / Double(recent.count), reviewed: recent.count)
    }

    func assignBlockID(_ prompt: Prompt) async throws -> String? {
        let text = try String(contentsOf: vault.url(for: prompt.path), encoding: .utf8)
        guard let (updated, id) = ClaimNote.ensureBlockID(in: text, line: prompt.line, prefix: "p") else { return nil }
        if updated != text {
            try await writer.write(updated, to: prompt.path, as: .user)
            _ = try await indexer.update(paths: [prompt.path])
        }
        let owner = MarkdownDocument(text: updated).frontmatter?["id"]?.text ?? prompt.path
        return "\(owner)#^\(id)"
    }
}

public enum ReviewError: Error, Equatable, CustomStringConvertible {
    case cannotIdentify(String)

    public var description: String {
        switch self {
        case .cannotIdentify(let path): "couldn't give the prompt in \(path) a block id"
        }
    }
}
