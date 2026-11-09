import Foundation
import KBCore

/// A retrieval prompt written in a note as a callout:
///
///     > [!prompt] What beats embedding choice?
///     > Hybrid search plus a reranker. ^p-k7h2qx
public struct Prompt: Sendable, Equatable, Identifiable {
    public let path: String
    public let question: String
    public let answer: String
    /// One-based file line of the callout's first line.
    public let line: Int
    public let blockID: String?
    /// Stable identity in `reviews.jsonl`: the note's id (or path) and the block id.
    public let key: String?
    public var id: String { key ?? "\(path):\(line)" }
}

public enum PromptParser {
    /// Every `> [!prompt]` callout in a note, in order.
    public static func prompts(in text: String, path: String) -> [Prompt] {
        let document = MarkdownDocument(text: text)
        let owner = document.frontmatter?["id"]?.text ?? path
        let blocks = BlockParser.scan(document.bodyLines).blocks.filter { $0.kind == .callout && $0.calloutType == "prompt" }
        return blocks.map { block in
            var lines = document.lines[(block.startLine - 1)...(block.endLine - 1)].map { stripQuote($0.text) }
            let first = lines.removeFirst()
            var question = first.replacingOccurrences(of: #"^\[!prompt\][+-]?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            var answer = lines.joined(separator: "\n")
            question = stripBlockID(question)
            answer = stripBlockID(answer).trimmingCharacters(in: .whitespacesAndNewlines)
            // "Q? A" on one line is also fine: no answer lines means the question line holds both.
            return Prompt(path: path, question: question.trimmingCharacters(in: .whitespaces), answer: answer, line: block.startLine,
                          blockID: block.blockID, key: block.blockID.map { "\(owner)#^\($0)" })
        }
    }

    static func stripQuote(_ line: String) -> String {
        var text = Substring(line.trimmingCharacters(in: .whitespaces))
        if text.hasPrefix(">") { text = text.dropFirst() }
        if text.hasPrefix(" ") { text = text.dropFirst() }
        return String(text)
    }

    static func stripBlockID(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*\^[A-Za-z0-9-]+\s*$"#, with: "", options: .regularExpression)
    }

    /// Callout lines for a new prompt (with a fresh block id), as "Make prompts" proposes them.
    public static func render(question: String, answer: String, blockID: String = "p-" + String(ULID().string.suffix(6)).lowercased()) -> [String] {
        let answerLines = answer.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }
        var lines = ["> [!prompt] \(question.replacingOccurrences(of: "\n", with: " "))"] + answerLines
        lines[lines.count - 1] += " ^\(blockID)"
        return lines
    }
}

/// One line of `.granite/reviews.jsonl`: the review history lives in the vault, as text, and the
/// schedule is rebuilt by replaying it (master plan §4.6).
public struct ReviewEvent: Sendable, Codable, Equatable {
    public let ts: Date
    public let prompt: String
    public let grade: Int
    /// Seconds from showing the question to grading.
    public let seconds: Double?

    public init(ts: Date, prompt: String, grade: Grade, seconds: Double? = nil) {
        self.ts = ts
        self.prompt = prompt
        self.grade = grade.rawValue
        self.seconds = seconds
    }
}

public enum ReviewLog {
    public static let path = ".granite/reviews.jsonl"

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func line(_ event: ReviewEvent) -> String {
        (try? String(decoding: encoder.encode(event), as: UTF8.self)) ?? ""
    }

    /// Events in file order; malformed lines (a bad merge, a hand edit) are skipped.
    public static func events(in text: String) -> [ReviewEvent] {
        text.split(separator: "\n").compactMap { try? decoder.decode(ReviewEvent.self, from: Data($0.utf8)) }
    }

    /// The schedule: each prompt's state after replaying its reviews in time order.
    public static func replay(_ events: [ReviewEvent], fsrs: FSRS = FSRS()) -> [String: CardState] {
        var cards: [String: CardState] = [:]
        for event in events.sorted(by: { $0.ts < $1.ts }) {
            guard let grade = Grade(rawValue: event.grade) else { continue }
            cards[event.prompt] = fsrs.review(cards[event.prompt], grade: grade, now: event.ts)
        }
        return cards
    }
}
