import Foundation

/// The weekly review's output (master plan §7, idea 11): your answers, in your words, as a
/// `Daily/YYYY-Www.md` note (origin human). Nothing a model wrote goes in it.
public enum WeeklyNote {
    /// The questions asked before anything else, every week.
    public static let questions = [
        "What changed your mind this week?",
        "Which claim would you defend least, and why?",
        "What did you capture that you haven't made sense of yet?",
        "What will you think about next week?",
    ]

    /// ISO-8601 week: "2026-W45".
    public static func week(of date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    public static func path(for week: String) -> String { "Daily/\(week).md" }

    /// A new weekly note, or `existing` with these answers added under their questions.
    /// Empty answers are left out; an answer to a question already in the note is appended to it.
    public static func render(week: String, answers: [(question: String, answer: String)], existing: String? = nil,
                              date: String, id: ULID = ULID()) -> String {
        var text = existing ?? [
            "---", "id: \(id.string)", "type: daily", "kind: weekly", "origin: human", "created: \(date)", "---",
            "# Week \(week)", "",
        ].joined(separator: "\n")
        for (question, answer) in answers {
            let body = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            let heading = "## \(question)"
            if let range = text.range(of: heading + "\n") {
                // Insert at the end of that section (before the next heading).
                let rest = text[range.upperBound...]
                let end = rest.range(of: "\n## ")?.lowerBound ?? text.endIndex
                let before = text[..<end].trimmingCharacters(in: .newlines)
                text = before + "\n\n" + body + "\n" + (end == text.endIndex ? "" : String(text[end...]))
            } else {
                if !text.hasSuffix("\n") { text += "\n" }
                if !text.hasSuffix("\n\n") { text += "\n" }
                text += heading + "\n" + body + "\n"
            }
        }
        return text
    }
}
