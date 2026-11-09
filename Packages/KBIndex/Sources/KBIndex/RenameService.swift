import Foundation
import GRDB
import KBCore

public struct RenameReport: Sendable, Equatable {
    public let from: String
    public let to: String
    /// Notes whose links were rewritten (vault-relative paths, after the move).
    public let rewrittenFiles: [String]
    public let rewrittenLinks: Int
}

public enum RenameError: Error, CustomStringConvertible, Equatable {
    case notIndexed(String)
    case notMarkdown(String)

    public var description: String {
        switch self {
        case .notIndexed(let path): "\(path) is not an indexed note"
        case .notMarkdown(let path): "a note must end in .md: \(path)"
        }
    }
}

/// Renames or moves a note and rewrites every link to it, using the index to find exactly which
/// lines of which notes hold those links (code blocks and prose mentions are never touched).
public actor RenameService {
    public let database: IndexDatabase
    public let indexer: Indexer
    let writer: SafeWriter

    public init(indexer: Indexer, writer: SafeWriter) {
        self.indexer = indexer
        self.database = indexer.database
        self.writer = writer
    }

    struct Incoming: Sendable {
        let source: String
        let line: Int
        let syntax: String
        let target: String
    }

    public func rename(from: String, to: String) async throws -> RenameReport {
        guard to.lowercased().hasSuffix(".md") else { throw RenameError.notMarkdown(to) }
        guard let rowid = try await database.pool.read({ db in
            try Int64.fetchOne(db, sql: "SELECT rowid FROM objects WHERE path = ?", arguments: [from])
        }) else { throw RenameError.notIndexed(from) }

        let incoming = try await database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT o.path, l.line, l.syntax, l.target_text FROM links l JOIN objects o ON o.rowid = l.src
                WHERE l.dst = ? AND l.target_key != ''
                """, arguments: [rowid])
            .map { Incoming(source: $0["path"], line: $0["line"], syntax: $0["syntax"], target: $0["target_text"]) }
        }
        let newTitle = NoteParser.title(for: to)
        let titleIsUnique = try await database.pool.read { db in
            (try Int.fetchOne(db, sql: "SELECT count(*) FROM objects WHERE name_key = ? AND rowid != ?",
                              arguments: [newTitle.lowercased(), rowid]) ?? 0) == 0
        }

        try await writer.move(from: from, to: to, as: .user)

        var rewritten: [String] = []
        var count = 0
        let vault = indexer.vault
        for (source, links) in Dictionary(grouping: incoming, by: \.source) {
            let path = source == from ? to : source
            guard let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { continue }
            let (updated, changed) = Self.rewrite(text, sourcePath: path, links: links, oldPath: from, newPath: to,
                                                  newTitle: newTitle, titleIsUnique: titleIsUnique)
            guard changed > 0, updated != text else { continue }
            try await writer.write(updated, to: path, as: .user)
            rewritten.append(path)
            count += changed
        }
        _ = try await indexer.update(paths: [from, to] + rewritten)
        return RenameReport(from: from, to: to, rewrittenFiles: rewritten.sorted(), rewrittenLinks: count)
    }

    // MARK: Rewriting

    /// The new target text for a wikilink that used `old`: bare names stay bare when unique,
    /// path-style links get the new path; a written ".md" suffix is kept.
    static func newWikiTarget(old: String, newPath: String, newTitle: String, titleIsUnique: Bool) -> String {
        let hadExtension = old.lowercased().hasSuffix(".md")
        let pathStyle = old.contains("/") || !titleIsUnique
        var target = pathStyle ? String(newPath.dropLast(3)) : newTitle
        if hadExtension { target += ".md" }
        return target
    }

    static func rewrite(_ text: String, sourcePath: String, links: [Incoming], oldPath: String, newPath: String,
                        newTitle: String, titleIsUnique: Bool) -> (String, Int) {
        var lines = Lines.split(text)
        guard !lines.isEmpty else { return (text, 0) }
        let document = MarkdownDocument(text: text)
        let frontmatterLines = document.frontmatter != nil ? Array(1..<max(1, document.bodyStart - 1)) : []
        var changes = 0

        func replace(at index: Int, _ transform: (String) -> (String, Int)) {
            guard lines.indices.contains(index) else { return }
            let (updated, n) = transform(lines[index].text)
            guard n > 0 else { return }
            lines[index] = Line(text: updated, index: index, terminator: lines[index].terminator)
            changes += n
        }

        for link in links {
            let indexes = link.line == 0 ? frontmatterLines : [link.line - 1]
            for index in indexes {
                if link.syntax == LinkRef.Syntax.markdown.rawValue {
                    replace(at: index) { rewriteMarkdownLinks(in: $0, sourcePath: sourcePath, oldPath: oldPath, newPath: newPath) }
                } else {
                    let target = newWikiTarget(old: link.target, newPath: newPath, newTitle: newTitle, titleIsUnique: titleIsUnique)
                    replace(at: index) { rewriteWikilinks(in: $0, old: link.target, new: target) }
                }
            }
        }
        let output = lines.map { $0.text + $0.terminator }.joined()
        return ((text.hasPrefix("\u{FEFF}") ? "\u{FEFF}" : "") + output, changes)
    }

    /// `[[old`, `[[old#…`, `[[old|…`, `![[old]]` (case-insensitive, Obsidian-style) → new target.
    static func rewriteWikilinks(in line: String, old: String, new: String) -> (String, Int) {
        let pattern = "(!?\\[\\[)\\s*" + NSRegularExpression.escapedPattern(for: old) + "\\s*(?=[#|\\]\\\\])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return (line, 0) }
        let range = NSRange(line.startIndex..., in: line)
        let count = regex.numberOfMatches(in: line, range: range)
        guard count > 0 else { return (line, 0) }
        let template = "$1" + NSRegularExpression.escapedTemplate(for: new)
        return (regex.stringByReplacingMatches(in: line, range: range, withTemplate: template), count)
    }

    /// `[text](relative/path.md#anchor)` whose path resolves to `oldPath` → path relative to the new location.
    static func rewriteMarkdownLinks(in line: String, sourcePath: String, oldPath: String, newPath: String) -> (String, Int) {
        guard let regex = try? NSRegularExpression(pattern: "\\]\\((<[^>]+>|[^)\\s]+)", options: []) else { return (line, 0) }
        let source = line as NSString
        var result = ""
        var cursor = 0
        var count = 0
        let sourceFolder = sourcePath.split(separator: "/").dropLast().map(String.init)
        for match in regex.matches(in: line, range: NSRange(location: 0, length: source.length)) {
            let destinationRange = match.range(at: 1)
            var destination = source.substring(with: destinationRange)
            let angled = destination.hasPrefix("<")
            if angled { destination = String(destination.dropFirst().dropLast()) }
            let parts = destination.split(separator: "#", maxSplits: 1).map(String.init)
            let rawPath = parts.first ?? ""
            let anchor = parts.count > 1 ? "#" + parts[1] : ""
            let decoded = rawPath.removingPercentEncoding ?? rawPath
            guard resolve(decoded, from: sourceFolder).lowercased() == oldPath.lowercased() else { continue }
            var relative = relativePath(to: newPath, from: sourceFolder)
            if !angled && (rawPath.contains("%20") || relative.contains(" ")) {
                relative = relative.replacingOccurrences(of: " ", with: "%20")
            }
            let replacement = angled ? "<\(relative)\(anchor)>" : relative + anchor
            result += source.substring(with: NSRange(location: cursor, length: destinationRange.location - cursor)) + replacement
            cursor = destinationRange.location + destinationRange.length
            count += 1
        }
        guard count > 0 else { return (line, 0) }
        result += source.substring(from: cursor)
        return (result, count)
    }

    static func resolve(_ relative: String, from folder: [String]) -> String {
        var parts = folder
        for part in relative.split(separator: "/") {
            switch part {
            case ".": continue
            case "..": if !parts.isEmpty { parts.removeLast() }
            default: parts.append(String(part))
            }
        }
        return parts.joined(separator: "/")
    }

    static func relativePath(to target: String, from folder: [String]) -> String {
        let targetParts = target.split(separator: "/").map(String.init)
        var common = 0
        while common < folder.count, common < targetParts.count - 1, folder[common] == targetParts[common] { common += 1 }
        let ups = Array(repeating: "..", count: folder.count - common)
        return (ups + targetParts[common...]).joined(separator: "/")
    }
}
