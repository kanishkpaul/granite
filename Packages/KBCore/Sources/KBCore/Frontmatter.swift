import Foundation
import Yams

/// A YAML property value. Obsidian properties are flat, but nested maps are tolerated on read.
public indirect enum PropertyValue: Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    /// YAML timestamps are kept as written ("2026-11-08"), never reformatted.
    case date(String)
    case list([PropertyValue])
    case map([String: PropertyValue])
    case null

    /// Scalar text, or nil for lists, maps and null.
    public var text: String? {
        switch self {
        case .string(let value), .date(let value): value
        case .number(let value):
            value.rounded() == value && abs(value) < 1e15 ? String(Int64(value)) : String(value)
        case .bool(let value): value ? "true" : "false"
        case .list, .map, .null: nil
        }
    }

    /// The value as a list of strings: a list's scalar items, or a single scalar.
    public var strings: [String] {
        switch self {
        case .list(let items): items.compactMap(\.text)
        case .null: []
        case .map: []
        default: text.map { [$0] } ?? []
        }
    }
}

public struct Property: Sendable, Hashable {
    public let key: String
    public let value: PropertyValue
}

/// The YAML block at the top of a note.
public struct Frontmatter: Sendable, Hashable {
    /// YAML text between the fences, exactly as in the file.
    public let raw: String
    /// Top-level properties in file order. Empty when `error` is set.
    public let properties: [Property]
    /// Set when the YAML did not parse. The note still indexes; its properties are ignored.
    public let error: String?

    public subscript(key: String) -> PropertyValue? {
        properties.first { $0.key == key }?.value
    }

    public static func parse(yaml raw: String) -> Frontmatter {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Frontmatter(raw: raw, properties: [], error: nil)
        }
        do {
            guard let node = try Yams.compose(yaml: raw) else {
                return Frontmatter(raw: raw, properties: [], error: nil)
            }
            guard case .mapping(let mapping) = node else {
                return Frontmatter(raw: raw, properties: [], error: "frontmatter is not a mapping")
            }
            var properties: [Property] = []
            for (keyNode, valueNode) in mapping {
                guard let key = keyNode.string else { continue }
                properties.append(Property(key: key, value: convert(valueNode)))
            }
            return Frontmatter(raw: raw, properties: properties, error: nil)
        } catch {
            return Frontmatter(raw: raw, properties: [], error: String(describing: error))
        }
    }

    static func convert(_ node: Node) -> PropertyValue {
        switch node {
        case .scalar(let scalar):
            let name = Tag.Name(rawValue: node.tag.rawValue)
            if name == .null { return .null }
            if name == .bool, let value = node.bool { return .bool(value) }
            if name == .int, let value = node.int { return .number(Double(value)) }
            if name == .float, let value = node.float { return .number(value) }
            if name == .timestamp { return .date(scalar.string) }
            return .string(scalar.string)
        case .sequence(let sequence):
            return .list(sequence.map(convert))
        case .mapping(let mapping):
            var map: [String: PropertyValue] = [:]
            for (keyNode, valueNode) in mapping {
                if let key = keyNode.string { map[key] = convert(valueNode) }
            }
            return .map(map)
        case .alias:
            return .null
        }
    }
}

/// A Markdown file split into its frontmatter and body.
public struct MarkdownDocument: Sendable {
    public let lines: [Line]
    public let frontmatter: Frontmatter?
    /// Index into `lines` where the body starts (after the closing fence).
    public let bodyStart: Int

    public var bodyLines: ArraySlice<Line> { lines[bodyStart...] }

    public init(text: String) {
        var source = text
        if source.hasPrefix("\u{FEFF}") { source.removeFirst() }
        let lines = Lines.split(source)
        self.lines = lines
        guard let first = lines.first, first.text.trimmingTrailingWhitespace() == "---", lines.count > 1 else {
            self.frontmatter = nil
            self.bodyStart = 0
            return
        }
        for line in lines.dropFirst() {
            let trimmed = line.text.trimmingTrailingWhitespace()
            if trimmed == "---" || trimmed == "..." {
                let yaml = lines[1..<line.index].map { $0.text }.joined(separator: "\n")
                self.frontmatter = Frontmatter.parse(yaml: yaml)
                self.bodyStart = line.index + 1
                return
            }
        }
        // No closing fence: Obsidian renders the whole file as body.
        self.frontmatter = nil
        self.bodyStart = 0
    }
}

/// Minimal-diff frontmatter edits. granite never re-serializes your YAML: it inserts or
/// replaces one line so the rest of the file stays byte-identical.
public enum FrontmatterEditor {
    public struct InvalidYAML: Error, CustomStringConvertible, Sendable {
        public let description: String
    }

    /// Sets a top-level scalar property. Replaces a single-line `key: value` if present,
    /// otherwise inserts `key: value` as the first property (creating the block if needed).
    /// Throws `InvalidYAML` rather than edit frontmatter it cannot read.
    public static func setScalar(_ key: String, to value: String, in text: String) throws -> String {
        let hasBOM = text.hasPrefix("\u{FEFF}")
        let document = MarkdownDocument(text: text)
        if let error = document.frontmatter?.error { throw InvalidYAML(description: error) }
        let newline = Lines.preferredTerminator(in: document.lines)
        let rendered = "\(key): \(yamlScalar(value))"
        var output: [String]

        if document.frontmatter != nil {
            let fenceEnd = document.bodyStart - 1
            var lines = document.lines.map { $0.text + $0.terminator }
            if let existing = (1..<fenceEnd).first(where: { isTopLevelKey(key, line: document.lines[$0].text) }) {
                let next = existing + 1
                let isMultiline = next < fenceEnd && isContinuation(document.lines[next].text)
                if !isMultiline {
                    lines[existing] = rendered + document.lines[existing].terminator
                    return (hasBOM ? "\u{FEFF}" : "") + lines.joined()
                }
            }
            lines.insert(rendered + newline, at: 1)
            output = lines
        } else {
            output = ["---" + newline, rendered + newline, "---" + newline]
            output.append(contentsOf: document.lines.map { $0.text + $0.terminator })
        }
        return (hasBOM ? "\u{FEFF}" : "") + output.joined()
    }

    static func isTopLevelKey(_ key: String, line: String) -> Bool {
        guard line.hasPrefix(key) else { return false }
        let rest = line.dropFirst(key.count)
        return rest.first == ":"
    }

    static func isContinuation(_ line: String) -> Bool {
        line.hasPrefix(" ") || line.hasPrefix("\t") || line.hasPrefix("-")
    }

    /// Quotes a scalar only when plain YAML would misread it.
    public static func yamlScalar(_ value: String) -> String {
        let needsQuotes = value.isEmpty
            || value.contains(": ") || value.contains(" #")
            || value.first.map { "[]{}&*!|>'\"%@`#,?-:".contains($0) || $0 == " " } ?? false
            || value.last == " "
            || ["true", "false", "yes", "no", "null", "~", "on", "off"].contains(value.lowercased())
            || Double(value) != nil
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

extension String {
    func trimmingTrailingWhitespace() -> String {
        var end = endIndex
        while end > startIndex {
            let previous = index(before: end)
            guard self[previous] == " " || self[previous] == "\t" else { break }
            end = previous
        }
        return String(self[startIndex..<end])
    }
}
