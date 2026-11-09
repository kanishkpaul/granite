import Foundation
import KBCore

/// What granite knows about a paper before you've read it.
public struct PaperMetadata: Sendable, Equatable {
    public var title: String
    public var authors: [String]
    public var year: Int?
    public var doi: String?
    public var pageCount: Int

    public init(title: String, authors: [String] = [], year: Int? = nil, doi: String? = nil, pageCount: Int = 0) {
        self.title = title
        self.authors = authors
        self.year = year
        self.doi = doi
        self.pageCount = pageCount
    }
}

/// Where a paper's three files live in the vault (decision 0008): the literature note you write in,
/// the PDF, and the extracted text that search and Q&A read, one `## Page N` section per page.
public struct PaperPaths: Sendable, Equatable {
    public let citekey: String
    public var note: String { "Papers/\(citekey).md" }
    public var pdf: String { "Papers/pdf/\(citekey).pdf" }
    public var text: String { "Papers/text/\(citekey).md" }

    public init(citekey: String) { self.citekey = citekey }

    /// The citekey of any of the three paths, if it is one.
    public static func citekey(of path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.first == "Papers", let last = parts.last else { return nil }
        switch parts.count {
        case 2 where last.hasSuffix(".md"): return String(last.dropLast(3))
        case 3 where parts[1] == "pdf" && last.hasSuffix(".pdf"): return String(last.dropLast(4))
        case 3 where parts[1] == "text" && last.hasSuffix(".md"): return String(last.dropLast(3))
        default: return nil
        }
    }
}

public enum Citekey {
    static let skipWords: Set<String> = ["a", "an", "the", "on", "of", "in", "for", "and", "to", "with", "towards", "toward"]

    /// "smith2024attention": first author's family name, year, first meaningful title word; ASCII,
    /// lowercased. Collisions get a, b, c… like BibTeX tools do.
    public static func make(for metadata: PaperMetadata, existing: Set<String>) -> String {
        let family = metadata.authors.first.map(familyName) ?? ""
        let words = metadata.title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { ascii(String($0)) }
            .filter { !$0.isEmpty }
        let word = words.first { !skipWords.contains($0) } ?? words.first ?? "paper"
        var base = ascii(family) + (metadata.year.map(String.init) ?? "") + word
        if family.isEmpty {
            // No author: title words first, so the key never starts with a digit ("contextual2024").
            base = metadata.year.map { word + String($0) } ?? words.filter { !skipWords.contains($0) }.prefix(2).joined()
        }
        if base.isEmpty { base = "paper" }
        base = String(base.prefix(40))
        let taken = Set(existing.map { $0.lowercased() })
        guard taken.contains(base) else { return base }
        for suffix in "bcdefghijklmnopqrstuvwxyz" where !taken.contains(base + String(suffix)) {
            return base + String(suffix)
        }
        return base + "-" + String(ULID().string.suffix(6)).lowercased()
    }

    /// "Smith, J." → "smith"; "Jane Smith" → "smith"; "Anthropic" → "anthropic".
    static func familyName(_ author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespaces)
        if let comma = trimmed.firstIndex(of: ",") { return String(trimmed[..<comma]) }
        return trimmed.split(separator: " ").last.map(String.init) ?? trimmed
    }

    static func ascii(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        return String(folded.lowercased().unicodeScalars.filter { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains(Character($0))) }
            .map(Character.init))
    }
}

/// Plain functions over extracted text: DOI, year, title fallback, page cleanup.
public enum PaperText {
    /// The first DOI in the text, without trailing punctuation.
    public static func doi(in text: String) -> String? {
        guard let range = text.range(of: #"10\.\d{4,9}/[^\s"<>]+"#, options: .regularExpression) else { return nil }
        var doi = String(text[range])
        while let last = doi.last, ".,;:)]}".contains(last) { doi.removeLast() }
        return doi
    }

    /// A plausible publication year (1900 to next year) from the first page.
    public static func year(in text: String, now: Date = Date()) -> Int? {
        let latest = Calendar(identifier: .gregorian).component(.year, from: now) + 1
        let pattern = #"\b(19|20)\d{2}\b"#
        var search = text.startIndex..<text.endIndex
        while let range = text.range(of: pattern, options: .regularExpression, range: search) {
            if let year = Int(text[range]), (1900...latest).contains(year) { return year }
            search = range.upperBound..<text.endIndex
        }
        return nil
    }

    /// The first substantial line of the first page, when the PDF has no title attribute.
    public static func titleGuess(fromFirstPage text: String) -> String? {
        for line in text.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            let letters = line.filter(\.isLetter).count
            guard letters >= 8, line.count <= 200, !line.lowercased().hasPrefix("arxiv"),
                  line.range(of: #"^\d"#, options: .regularExpression) == nil else { continue }
            return line
        }
        return nil
    }

    /// PDF page text → readable Markdown: rejoins wrapped lines and hyphenated words, keeps
    /// paragraph breaks, and escapes what Markdown would misread (headings, quotes, fences).
    public static func clean(_ page: String) -> String {
        let lines = page.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let lengths = lines.map(\.count).filter { $0 > 0 }.sorted()
        let typical = lengths.isEmpty ? 0 : lengths[lengths.count / 2]
        var paragraphs: [String] = []
        var current = ""
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = ""
                continue
            }
            if current.isEmpty {
                current = line
            } else if current.hasSuffix("-"), let first = line.first, first.isLowercase {
                current.removeLast()
                current += line
            } else {
                current += " " + line
            }
            // A short line that ends a sentence usually ends a paragraph; a very short one is a
            // title, byline or heading.
            let endsSentence = line.last.map { ".!?:".contains($0) } ?? false
            if !line.hasSuffix("-"), line.count < max(20, typical * 3 / 4), endsSentence || line.count < typical * 6 / 10 {
                paragraphs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs.map(escape).joined(separator: "\n\n")
    }

    static func escape(_ paragraph: String) -> String {
        var text = paragraph
        if let first = text.first, "#>|".contains(first) { text = "\\" + text }
        if text.hasPrefix("```") || text.hasPrefix("~~~") || text.hasPrefix("---") { text = "\\" + text }
        // A trailing "^word" would be read as a block id.
        if let caret = text.lastIndex(of: "^"), !text[caret...].contains(" ") { text.insert("\\", at: caret) }
        return text.replacingOccurrences(of: "[[", with: "[\\[")
    }

    /// The page-text note: one `## Page N` section per page, so search hits carry their page.
    public static func textNote(paths: PaperPaths, title: String, pages: [String], ocr: Bool) -> String {
        var lines = ["---", "type: source", "kind: paper-text", "origin: source",
                     "paper: \"[[\(paths.citekey)]]\"", "pdf: \(FrontmatterEditor.yamlScalar(paths.pdf))"]
        if ocr { lines.append("text: ocr") }
        lines += ["---", "# \(title) (full text)", ""]
        for (index, page) in pages.enumerated() {
            lines.append("## Page \(index + 1)")
            let cleaned = clean(page)
            lines.append(cleaned.isEmpty ? "*(no text on this page)*" : cleaned)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// The page number of a `## Page N` heading path from the text note.
    public static func page(fromHeadingPath path: String) -> Int? {
        guard let range = path.range(of: #"Page (\d+)"#, options: .regularExpression) else { return nil }
        return Int(path[range].dropFirst(5))
    }
}
