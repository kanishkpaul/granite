import Foundation

/// A claim's lifecycle (master plan §4.5). Only claims you promote are truth.
public enum ClaimStatus: String, Sendable, Codable, CaseIterable {
    case proposed, held, revised, superseded, retired
}

/// Pure text operations for the claim ledger (master plan §7, idea 5).
public enum ClaimNote {
    /// A claim file: one assertion, its status, confidence and evidence.
    public static func render(text: String, sources: [String] = [], supersedes: [String] = [], confidence: Double = 0.7,
                              date: String, status: ClaimStatus = .held, origin: Origin = .human, id: ULID = ULID()) -> String {
        func list(_ links: [String]) -> String {
            "[" + links.map { "\"\($0.replacingOccurrences(of: "\"", with: "'"))\"" }.joined(separator: ", ") + "]"
        }
        let clamped = min(1, max(0, confidence))
        let lines = [
            "---", "id: \(id.string)", "type: claim", "origin: \(origin.rawValue)", "created: \(date)", "as_of: \(date)",
            "status: \(status.rawValue)", "confidence: \(String(format: "%.2f", clamped))",
            "supersedes: \(list(supersedes))", "source: \(list(sources))", "supports: []", "contradicts: []", "tags: []", "---",
            text.trimmingCharacters(in: .whitespacesAndNewlines), "",
        ]
        return lines.joined(separator: "\n")
    }

    /// A file name for a claim: its first sentence, shortened at a word boundary.
    public static func title(for text: String, maxLength: Int = 80) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        var sentence = flat
        if let end = flat.firstIndex(where: { ".!?".contains($0) }), flat.distance(from: flat.startIndex, to: end) >= 12 {
            sentence = String(flat[..<end])
        }
        guard sentence.count > maxLength else { return sentence }
        let cut = sentence.prefix(maxLength)
        return String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)])
    }

    /// The block covering `line` (one-based, in the whole file) gets a `^id` if it has none.
    /// Returns the updated text and the block id; nil for headings, code, math, tables and frontmatter.
    public static func ensureBlockID(in text: String, line: Int, prefix: String = "c") -> (text: String, id: String)? {
        let document = MarkdownDocument(text: text)
        let blocks = BlockParser.scan(document.bodyLines).blocks
        guard let block = blocks.first(where: { $0.startLine <= line && line <= $0.endLine }),
              [.paragraph, .listItem, .quote, .callout].contains(block.kind) else { return nil }
        if let existing = block.blockID { return (text, existing) }
        let id = "\(prefix)-" + String(ULID().string.suffix(6)).lowercased()
        var lines = document.lines
        let index = block.endLine - 1
        guard lines.indices.contains(index) else { return nil }
        let current = lines[index]
        lines[index] = Line(text: current.text.trimmingTrailingWhitespace() + " ^\(id)", index: index, terminator: current.terminator)
        return ((text.hasPrefix("\u{FEFF}") ? "\u{FEFF}" : "") + lines.map { $0.text + $0.terminator }.joined(), id)
    }
}
