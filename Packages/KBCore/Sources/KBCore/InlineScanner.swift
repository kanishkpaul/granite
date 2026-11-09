/// A link found in a note: inline wikilink, embed, Markdown link, or a typed frontmatter relation.
public struct LinkRef: Sendable, Hashable {
    public enum Syntax: String, Sendable, Codable {
        case wikilink, markdown
    }

    /// Target as written, without anchor or alias ("Folder/Note", "Note.md", "" for self-links).
    public let target: String
    public let heading: String?
    public let blockID: String?
    public let alias: String?
    public let isEmbed: Bool
    public let syntax: Syntax
    /// "links", "embed", or a `Relation` raw value for typed frontmatter links.
    public let relation: String
    /// One-based file line; 0 for frontmatter links.
    public let line: Int

    public init(target: String, heading: String? = nil, blockID: String? = nil, alias: String? = nil,
                isEmbed: Bool = false, syntax: Syntax = .wikilink, relation: String = Relation.untyped, line: Int = 0) {
        self.target = target
        self.heading = heading
        self.blockID = blockID
        self.alias = alias
        self.isEmbed = isEmbed
        self.syntax = syntax
        self.relation = relation
        self.line = line
    }

    /// Lowercased lookup key without a trailing ".md": "folder/note".
    public var targetKey: String {
        LinkRef.key(for: target)
    }

    public static func key(for target: String) -> String {
        var key = target.trimmingCharacters(in: .whitespaces)
        if key.lowercased().hasSuffix(".md") { key.removeLast(3) }
        return key.lowercased()
    }

    /// Parses the inside of `[[...]]`: "target#heading|alias" or "target#^block|alias".
    public static func parseWikilink(_ inner: String, isEmbed: Bool, relation: String, line: Int) -> LinkRef {
        var body = inner.replacingOccurrences(of: "\\|", with: "|")
        var alias: String?
        if let bar = body.firstIndex(of: "|") {
            alias = String(body[body.index(after: bar)...]).trimmingCharacters(in: .whitespaces)
            body = String(body[..<bar])
        }
        var target = body
        var heading: String?
        var blockID: String?
        if let hash = body.firstIndex(of: "#") {
            target = String(body[..<hash])
            let anchor = String(body[body.index(after: hash)...])
            if anchor.hasPrefix("^") {
                blockID = String(anchor.dropFirst())
            } else if !anchor.isEmpty {
                // Nested headings "A#B" keep only the last segment, as Obsidian resolves them.
                heading = anchor.split(separator: "#").last.map(String.init)
            }
        }
        return LinkRef(target: target.trimmingCharacters(in: .whitespaces), heading: heading, blockID: blockID,
                       alias: alias, isEmbed: isEmbed, syntax: .wikilink, relation: relation, line: line)
    }
}

/// Scans one line of Markdown for Obsidian inline syntax, skipping inline code spans.
/// Hand-written over Unicode scalars: Swift `Regex` is too slow for a 50k-note index.
public enum InlineScanner {
    public struct Result: Sendable {
        public var links: [LinkRef] = []
        public var tags: [String] = []
    }

    public static func scan(_ text: String, line: Int) -> Result {
        var result = Result()
        let scalars = Array(text.unicodeScalars)
        let count = scalars.count
        var index = 0

        while index < count {
            let scalar = scalars[index]
            switch scalar {
            case "`":
                index = skipCodeSpan(scalars, from: index)
                continue
            case "\\":
                index += 2
                continue
            case "[":
                let isEmbed = index > 0 && scalars[index - 1] == "!"
                if index + 1 < count, scalars[index + 1] == "[",
                   let close = findWikilinkClose(scalars, from: index + 2) {
                    let inner = String(String.UnicodeScalarView(scalars[(index + 2)..<close]))
                    if !inner.isEmpty {
                        result.links.append(LinkRef.parseWikilink(inner, isEmbed: isEmbed,
                                                                  relation: isEmbed ? Relation.embed : Relation.untyped,
                                                                  line: line))
                    }
                    index = close + 2
                    continue
                }
                if let (link, end) = markdownLink(scalars, from: index, isEmbed: isEmbed, line: line) {
                    if let link { result.links.append(link) }
                    index = end
                    continue
                }
            case "#":
                let atBoundary = index == 0 || scalars[index - 1].properties.isWhitespace
                if atBoundary, let (tag, end) = readTag(scalars, from: index + 1) {
                    result.tags.append(tag)
                    index = end
                    continue
                }
            default:
                break
            }
            index += 1
        }
        return result
    }

    /// Returns the index after a code span, or after the opening run if it never closes.
    static func skipCodeSpan(_ scalars: [Unicode.Scalar], from start: Int) -> Int {
        var run = 0
        var index = start
        while index < scalars.count, scalars[index] == "`" { run += 1; index += 1 }
        var search = index
        while search < scalars.count {
            if scalars[search] == "`" {
                var closing = 0
                var probe = search
                while probe < scalars.count, scalars[probe] == "`" { closing += 1; probe += 1 }
                if closing == run { return probe }
                search = probe
            } else {
                search += 1
            }
        }
        return index
    }

    static func findWikilinkClose(_ scalars: [Unicode.Scalar], from start: Int) -> Int? {
        var index = start
        while index + 1 < scalars.count {
            let scalar = scalars[index]
            if scalar == "]" && scalars[index + 1] == "]" { return index }
            if scalar == "[" && scalars[index + 1] == "[" { return nil }
            index += 1
        }
        return nil
    }

    /// `[text](target)`: returns a link for relative note targets, nil for URLs.
    static func markdownLink(_ scalars: [Unicode.Scalar], from start: Int, isEmbed: Bool, line: Int) -> (LinkRef?, Int)? {
        var depth = 0
        var index = start
        var closeBracket: Int?
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\\" { index += 2; continue }
            if scalar == "[" { depth += 1 }
            if scalar == "]" {
                depth -= 1
                if depth == 0 { closeBracket = index; break }
            }
            index += 1
        }
        guard let bracket = closeBracket, bracket + 1 < scalars.count, scalars[bracket + 1] == "(" else { return nil }
        var cursor = bracket + 2
        var destination = ""
        if cursor < scalars.count, scalars[cursor] == "<" {
            cursor += 1
            while cursor < scalars.count, scalars[cursor] != ">" {
                destination.unicodeScalars.append(scalars[cursor]); cursor += 1
            }
            guard cursor < scalars.count else { return nil }
            cursor += 1
            while cursor < scalars.count, scalars[cursor] != ")" { cursor += 1 }
        } else {
            var parens = 0
            while cursor < scalars.count {
                let scalar = scalars[cursor]
                if scalar == "(" { parens += 1 }
                if scalar == ")" { if parens == 0 { break }; parens -= 1 }
                if scalar.properties.isWhitespace {
                    while cursor < scalars.count, scalars[cursor] != ")" { cursor += 1 }
                    break
                }
                destination.unicodeScalars.append(scalar)
                cursor += 1
            }
        }
        guard cursor < scalars.count, scalars[cursor] == ")" else { return nil }
        let end = cursor + 1
        let alias = String(String.UnicodeScalarView(scalars[(start + 1)..<bracket]))
        guard isNoteTarget(destination) else { return (nil, end) }
        let decoded = destination.removingPercentEncoding ?? destination
        var target = decoded
        var heading: String?
        var blockID: String?
        if let hash = decoded.firstIndex(of: "#") {
            target = String(decoded[..<hash])
            let anchor = String(decoded[decoded.index(after: hash)...])
            if anchor.hasPrefix("^") { blockID = String(anchor.dropFirst()) } else if !anchor.isEmpty { heading = anchor }
        }
        let link = LinkRef(target: target, heading: heading, blockID: blockID, alias: alias.isEmpty ? nil : alias,
                           isEmbed: isEmbed, syntax: .markdown,
                           relation: isEmbed ? Relation.embed : Relation.untyped, line: line)
        return (link, end)
    }

    /// Relative paths to notes only: no scheme, no absolute paths, and either `.md` or no extension.
    static func isNoteTarget(_ destination: String) -> Bool {
        guard !destination.isEmpty, !destination.hasPrefix("/") else { return false }
        if destination.hasPrefix("#") { return true }
        if let colon = destination.firstIndex(of: ":") {
            let scheme = destination[..<colon]
            if !scheme.isEmpty, scheme.allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) }) { return false }
        }
        let path = destination.split(separator: "#", maxSplits: 1).first.map(String.init) ?? destination
        let last = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = last.lastIndex(of: ".") else { return true }
        return last[last.index(after: dot)...].lowercased() == "md"
    }

    /// Obsidian tags: letters, digits, `_`, `-`, `/`; at least one non-digit.
    static func readTag(_ scalars: [Unicode.Scalar], from start: Int) -> (String, Int)? {
        var index = start
        var tag = String.UnicodeScalarView()
        var hasNonDigit = false
        while index < scalars.count {
            let scalar = scalars[index]
            let properties = scalar.properties
            let allowed = properties.isAlphabetic || properties.numericType != nil
                || scalar == "_" || scalar == "-" || scalar == "/" || properties.isEmoji && scalar.value > 0xFF
            guard allowed else { break }
            if properties.numericType == nil { hasNonDigit = true }
            tag.append(scalar)
            index += 1
        }
        guard !tag.isEmpty, hasNonDigit else { return nil }
        var text = String(tag)
        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty else { return nil }
        return (text, index)
    }
}
