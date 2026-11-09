/// A unit of a note that search and citations point to.
public struct Block: Sendable, Hashable {
    public enum Kind: String, Sendable, Codable {
        case heading, paragraph, listItem = "list_item", quote, callout, code, math, table
    }

    public let kind: Kind
    /// Block text with any trailing `^block-id` removed.
    public let text: String
    /// "H1 > H2" for the headings above this block.
    public let headingPath: String
    /// One-based, inclusive file lines.
    public let startLine: Int
    public let endLine: Int
    public let blockID: String?
    /// Callout type ("note", "prompt", …) for `> [!type]` blocks.
    public let calloutType: String?
    /// Heading level 1–6 for heading blocks.
    public let level: Int?
}

/// Body structure from one pass over the lines: blocks, inline links and tags.
/// Code and math blocks contribute text but no links or tags; `%% comments %%` contribute nothing.
public struct BodyScan: Sendable {
    public var blocks: [Block] = []
    public var links: [LinkRef] = []
    public var tags: [String] = []
}

public enum BlockParser {
    public static func scan<C: Collection>(_ lines: C) -> BodyScan where C.Element == Line {
        var state = State()
        for line in lines { state.consume(line) }
        state.flush()
        return state.scan
    }

    struct Pending {
        var kind: Block.Kind
        var lines: [String]
        var start: Int
        var end: Int
        var blockID: String?
        var calloutType: String?
        var level: Int?
    }

    struct State {
        var scan = BodyScan()
        var headings: [(level: Int, text: String)] = []
        var pending: Pending?
        var fence: (marker: Character, length: Int)?
        var inMath = false
        var inComment = false

        var headingPath: String { headings.map(\.text).joined(separator: " > ") }

        mutating func consume(_ line: Line) {
            let number = line.index + 1
            let text = line.text
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            if inComment {
                if trimmed.hasSuffix("%%") || trimmed.contains("%%") { inComment = false }
                return
            }
            if let open = fence {
                if isFenceClose(trimmed, marker: open.marker, length: open.length) {
                    pending?.end = number
                    fence = nil
                    flush()
                } else {
                    pending?.lines.append(text)
                    pending?.end = number
                }
                return
            }
            if inMath {
                if trimmed.hasSuffix("$$") {
                    pending?.end = number
                    inMath = false
                    flush()
                } else {
                    pending?.lines.append(text)
                    pending?.end = number
                }
                return
            }

            if trimmed.isEmpty { flush(); return }

            if trimmed.hasPrefix("%%") {
                flush()
                let rest = trimmed.dropFirst(2)
                if !rest.contains("%%") { inComment = true }
                return
            }
            if trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->") { flush(); return }

            if let opener = fenceOpen(trimmed) {
                flush()
                fence = opener
                pending = Pending(kind: .code, lines: [], start: number, end: number)
                return
            }
            if trimmed.hasPrefix("$$") {
                flush()
                let rest = trimmed.dropFirst(2)
                pending = Pending(kind: .math, lines: [], start: number, end: number)
                if rest.hasSuffix("$$") && rest.count >= 2 {
                    pending?.lines.append(String(rest.dropLast(2)))
                    flush()
                } else {
                    if !rest.isEmpty { pending?.lines.append(String(rest)) }
                    inMath = true
                }
                return
            }

            // A line holding only "^id" names the block above it.
            if let id = standaloneBlockID(trimmed) {
                if pending != nil {
                    pending?.blockID = id
                    flush()
                } else if let last = scan.blocks.popLast() {
                    scan.blocks.append(Block(kind: last.kind, text: last.text, headingPath: last.headingPath,
                                             startLine: last.startLine, endLine: number, blockID: id,
                                             calloutType: last.calloutType, level: last.level))
                }
                return
            }

            if let (level, title) = atxHeading(trimmed, raw: text) {
                flush()
                let (clean, id) = stripBlockID(title)
                while let last = headings.last, last.level >= level { headings.removeLast() }
                inline(clean, line: number)
                scan.blocks.append(Block(kind: .heading, text: clean, headingPath: headingPath, startLine: number,
                                         endLine: number, blockID: id, calloutType: nil, level: level))
                headings.append((level, clean))
                return
            }

            if isThematicBreak(trimmed) { flush(); return }

            let (clean, id) = stripBlockID(text)
            inline(clean, line: number)

            if trimmed.hasPrefix(">") {
                if let current = pending, current.kind == .quote || current.kind == .callout {
                    append(clean, line: number, id: id)
                } else {
                    flush()
                    let callout = calloutType(trimmed)
                    pending = Pending(kind: callout == nil ? .quote : .callout, lines: [clean], start: number,
                                      end: number, blockID: id, calloutType: callout)
                }
                return
            }
            if trimmed.hasPrefix("|") {
                if pending?.kind == .table { append(clean, line: number, id: id) } else {
                    flush()
                    pending = Pending(kind: .table, lines: [clean], start: number, end: number, blockID: id)
                }
                return
            }
            if isListItem(trimmed) {
                flush()
                pending = Pending(kind: .listItem, lines: [clean], start: number, end: number, blockID: id)
                return
            }
            if let current = pending, current.kind == .table || current.kind == .quote || current.kind == .callout {
                flush()
            }
            if pending == nil {
                pending = Pending(kind: .paragraph, lines: [clean], start: number, end: number, blockID: id)
            } else {
                append(clean, line: number, id: id)
            }
        }

        mutating func append(_ text: String, line: Int, id: String?) {
            pending?.lines.append(text)
            pending?.end = line
            if let id { pending?.blockID = id }
        }

        mutating func inline(_ text: String, line: Int) {
            let found = InlineScanner.scan(text, line: line)
            scan.links.append(contentsOf: found.links)
            scan.tags.append(contentsOf: found.tags)
        }

        mutating func flush() {
            guard let block = pending else { return }
            pending = nil
            let text = block.lines.joined(separator: "\n")
            scan.blocks.append(Block(kind: block.kind, text: text, headingPath: headingPath, startLine: block.start,
                                     endLine: block.end, blockID: block.blockID, calloutType: block.calloutType,
                                     level: block.level))
        }
    }

    static func fenceOpen(_ trimmed: String) -> (Character, Int)? {
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let run = trimmed.prefix { $0 == first }.count
        guard run >= 3 else { return nil }
        if first == "`" && trimmed.dropFirst(run).contains("`") { return nil }
        return (first, run)
    }

    static func isFenceClose(_ trimmed: String, marker: Character, length: Int) -> Bool {
        let run = trimmed.prefix { $0 == marker }.count
        return run >= length && trimmed.dropFirst(run).allSatisfy { $0 == " " || $0 == "\t" }
    }

    static func atxHeading(_ trimmed: String, raw: String) -> (Int, String)? {
        // Four or more leading spaces make an indented code line, not a heading.
        guard !raw.hasPrefix("    "), !raw.hasPrefix("\t") else { return nil }
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let rest = trimmed.dropFirst(level)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var title = rest.trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: "## Title ##".
        if let range = title.range(of: " #+$", options: .regularExpression) { title.removeSubrange(range) }
        if title.allSatisfy({ $0 == "#" }) { title = "" }
        return (level, title)
    }

    static func isThematicBreak(_ trimmed: String) -> Bool {
        let compact = trimmed.filter { $0 != " " }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    static func isListItem(_ trimmed: String) -> Bool {
        if let first = trimmed.first, "-*+".contains(first) {
            return trimmed.count == 1 || trimmed.dropFirst().first == " " || trimmed.dropFirst().first == "\t"
        }
        let digits = trimmed.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 9 else { return false }
        let rest = trimmed.dropFirst(digits.count)
        guard let marker = rest.first, marker == "." || marker == ")" else { return false }
        let after = rest.dropFirst()
        return after.isEmpty || after.first == " " || after.first == "\t"
    }

    static func calloutType(_ trimmed: String) -> String? {
        let afterMarker: Substring = trimmed.dropFirst().drop { $0 == " " }
        guard afterMarker.hasPrefix("[!") else { return nil }
        let inner: Substring = afterMarker.dropFirst(2)
        guard let close = inner.firstIndex(of: "]") else { return nil }
        let type = String(inner[inner.startIndex..<close]).lowercased()
        return type.isEmpty ? nil : type
    }

    /// A trailing " ^id" (letters, digits, dashes) at the end of a line.
    static func stripBlockID(_ text: String) -> (String, String?) {
        let trimmed = text.trimmingTrailingWhitespace()
        guard let caret = trimmed.lastIndex(of: "^") else { return (text, nil) }
        let id = trimmed[trimmed.index(after: caret)...]
        guard !id.isEmpty, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
            return (text, nil)
        }
        guard caret == trimmed.startIndex || trimmed[trimmed.index(before: caret)] == " " else { return (text, nil) }
        if caret == trimmed.startIndex { return (text, nil) }
        let before = String(trimmed[..<caret]).trimmingTrailingWhitespace()
        return (before, String(id))
    }

    static func standaloneBlockID(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("^"), trimmed.count > 1 else { return nil }
        let id = trimmed.dropFirst()
        guard id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return nil }
        return String(id)
    }
}
