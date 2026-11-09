import Foundation

/// A trail (master plan §7, idea 10): a `note` with `kind: trail`, an ordered list of links,
/// each with one sentence of your own. Candidate trails come as proposals; a trail only counts
/// once you've named it (`status: endorsed`).
public struct Trail: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        /// The link target as written ("Note", "Notes/Note#Heading").
        public let target: String
        /// Your sentence on why this comes next ("" if not written yet).
        public let sentence: String
        public let line: Int
    }

    public let title: String
    public let steps: [Step]
    public let endorsed: Bool

    /// Parses numbered or bulleted lines that start with a wikilink: `1. [[Note]] — why`.
    public static func parse(_ text: String, path: String) -> Trail? {
        let document = MarkdownDocument(text: text)
        guard document.frontmatter?["kind"]?.text == "trail" else { return nil }
        var steps: [Step] = []
        for line in document.bodyLines {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            guard let match = trimmed.firstMatch(of: /^(?:\d+[.)]|[-*+])\s+\[\[([^\]|#]+(?:#[^\]|]*)?)(?:\|[^\]]*)?\]\]\s*(?:[—–:-]\s*)?(.*)$/) else { continue }
            let sentence = String(match.output.2).trimmingCharacters(in: .whitespaces)
            steps.append(Step(target: String(match.output.1), sentence: sentence.hasPrefix("(") && sentence.hasSuffix(")") ? "" : sentence,
                              line: line.index + 1))
        }
        let heading = document.bodyLines.first { $0.text.hasPrefix("# ") }.map { String($0.text.dropFirst(2)) }
        return Trail(title: heading ?? NoteParser.title(for: path), steps: steps,
                     endorsed: document.frontmatter?["status"]?.text == "endorsed")
    }

    /// The lines of a candidate trail: your sentences are left as placeholders.
    public static func candidate(title: String, targets: [String], date: String, source: String) -> [String] {
        ["---", "type: note", "kind: trail", "origin: human", "status: candidate", "created: \(date)", "---",
         "# \(title)", "", "Candidate from \(source). Name it, write one sentence per step, then set `status: endorsed`.", ""]
            + targets.enumerated().map { index, target in "\(index + 1). [[\(target)]] — (why this comes next)" }
    }
}
