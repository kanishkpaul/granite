import Foundation
import KBCore

/// A passage you highlighted in the PDF view, kept in the literature note as a quote block.
public struct Highlight: Sendable, Equatable, Identifiable {
    /// Block id: "p3-k7h2qx" (page, then six characters).
    public let id: String
    public let page: Int
    public var text: String
    public var comment: String?

    public init(id: String? = nil, page: Int, text: String, comment: String? = nil) {
        self.id = id ?? "p\(page)-" + String(ULID().string.suffix(6)).lowercased()
        self.page = page
        self.text = text
        self.comment = comment
    }
}

/// The literature note (`Papers/<citekey>.md`): your take is yours; the region between the
/// `granite:pdf` markers is managed by the PDF view (highlights) and regenerated, nothing else is.
public enum LiteratureNote {
    public static let begin = "<!-- granite:pdf:begin (managed by the PDF view; edits inside are replaced) -->"
    public static let end = "<!-- granite:pdf:end -->"

    public static func render(paths: PaperPaths, metadata: PaperMetadata, created: String, id: ULID = ULID()) -> String {
        var lines = ["---", "id: \(id.string)", "type: source", "kind: paper", "origin: source",
                     "title: \(FrontmatterEditor.yamlScalar(metadata.title))", "citekey: \(paths.citekey)"]
        if let doi = metadata.doi { lines.append("doi: \(FrontmatterEditor.yamlScalar(doi))") }
        let authors = metadata.authors.map { "\"\($0.replacingOccurrences(of: "\"", with: "'"))\"" }.joined(separator: ", ")
        lines.append("authors: [\(authors)]")
        if let year = metadata.year { lines.append("year: \(year)") }
        lines += ["pdf: \(FrontmatterEditor.yamlScalar(paths.pdf))", "pages: \(metadata.pageCount)", "status: unread",
                  "created: \(created)", "---", "# \(metadata.title)", "",
                  "Full text: [[\(String(paths.text.dropLast(3)))|searchable text]] · PDF: [open](\(link(pdfPath: paths.pdf, page: 1, block: nil)))",
                  "", "## My take", "", "", begin, "## Highlights", "", end, ""]
        return lines.joined(separator: "\n")
    }

    /// Highlights in the managed region, in order.
    public static func highlights(in text: String) -> [Highlight] {
        guard let region = managedRegion(in: text) else { return [] }
        var result: [Highlight] = []
        var current: Highlight?
        for line in region.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("> ") {
                if let current { result.append(current) }
                var body = String(line.dropFirst(2))
                var id: String?
                if let range = body.range(of: #" \^(p\d+-[a-z0-9]+)$"#, options: .regularExpression) {
                    id = String(body[range].dropFirst(2))
                    body = String(body[..<range.lowerBound])
                }
                let page = id.flatMap { Int($0.dropFirst().prefix { $0.isNumber }) } ?? 0
                current = Highlight(id: id, page: page, text: unescape(body))
            } else if line.hasPrefix("Comment: "), current != nil {
                current?.comment = String(line.dropFirst("Comment: ".count))
            }
        }
        if let current { result.append(current) }
        return result
    }

    /// Adds or replaces a highlight (by id) in the managed region, creating the region if missing,
    /// sorted by page. Everything outside the region is left byte for byte.
    public static func upsert(_ highlight: Highlight, in text: String, pdfPath: String) -> String {
        var all = highlights(in: text).filter { $0.id != highlight.id }
        all.append(highlight)
        return replaceRegion(in: text, with: all, pdfPath: pdfPath)
    }

    public static func remove(id: String, in text: String, pdfPath: String) -> String {
        replaceRegion(in: text, with: highlights(in: text).filter { $0.id != id }, pdfPath: pdfPath)
    }

    static func replaceRegion(in text: String, with highlights: [Highlight], pdfPath: String) -> String {
        let sorted = highlights.enumerated().sorted { ($0.element.page, $0.offset) < ($1.element.page, $1.offset) }.map(\.element)
        var body = ["## Highlights", ""]
        for highlight in sorted {
            body.append("> \(escape(highlight.text)) ^\(highlight.id)")
            body.append("")
            body.append("p. \(highlight.page) · [open in PDF](\(link(pdfPath: pdfPath, page: highlight.page, block: highlight.id)))")
            if let comment = highlight.comment, !comment.isEmpty { body.append("Comment: \(comment.replacingOccurrences(of: "\n", with: " "))") }
            body.append("")
        }
        let region = ([begin] + body + [end]).joined(separator: "\n")
        if let beginRange = text.range(of: begin), let endRange = text.range(of: end, range: beginRange.upperBound..<text.endIndex) {
            return text.replacingCharacters(in: beginRange.lowerBound..<endRange.upperBound, with: region)
        }
        var output = text
        if !output.hasSuffix("\n") { output += "\n" }
        return output + "\n" + region + "\n"
    }

    static func managedRegion(in text: String) -> Substring? {
        guard let beginRange = text.range(of: begin),
              let endRange = text.range(of: end, range: beginRange.upperBound..<text.endIndex) else { return nil }
        return text[beginRange.upperBound..<endRange.lowerBound]
    }

    /// `granite://pdf?path=…&page=…&block=…`: opens the PDF view at the page with the quote marked.
    public static func link(pdfPath: String, page: Int, block: String?) -> String {
        var components = URLComponents()
        components.scheme = "granite"
        components.host = "pdf"
        components.queryItems = [URLQueryItem(name: "path", value: pdfPath), URLQueryItem(name: "page", value: String(page))]
            + (block.map { [URLQueryItem(name: "block", value: $0)] } ?? [])
        return components.string ?? "granite://pdf"
    }

    /// One line, no characters that would end the quote or start a link.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "[[", with: "[\\[")
            .trimmingCharacters(in: .whitespaces)
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "[\\[", with: "[[")
    }
}
