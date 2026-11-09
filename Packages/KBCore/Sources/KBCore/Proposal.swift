import Foundation

public enum ProposalKind: String, Sendable, Codable, CaseIterable {
    case link, edit, claim, merge, trail, prompt, tag, rule
    /// A decision-record stub (code decisions, master plan §7 idea 8).
    case decision
}

public enum ProposalStatus: String, Sendable, Codable, CaseIterable {
    case open, accepted, edited, rejected
}

/// The `diff` block of a proposal: lines to remove, lines to add.
public struct ProposalChange: Sendable, Hashable {
    public var removed: [String]
    public var added: [String]

    public init(removed: [String] = [], added: [String]) {
        self.removed = removed
        self.added = added
    }

    /// "```diff" body: "- old" and "+ new" lines (a single space after the sign is optional).
    public static func parse(_ body: String) -> ProposalChange {
        var change = ProposalChange(removed: [], added: [])
        for line in Lines.split(body) {
            let text = line.text
            if text.hasPrefix("+") { change.added.append(Self.strip(text)) }
            else if text.hasPrefix("-") { change.removed.append(Self.strip(text)) }
        }
        return change
    }

    static func strip(_ line: String) -> String {
        var rest = line.dropFirst()
        if rest.first == " " { rest = rest.dropFirst() }
        return String(rest)
    }

    public var rendered: String {
        (removed.map { "- \($0)" } + added.map { "+ \($0)" }).joined(separator: "\n")
    }
}

/// An AI-proposed change to a note outside `AI/` (master plan §6.4). Nothing changes until you accept it.
public struct Proposal: Sendable, Hashable {
    public var kind: ProposalKind
    /// The note it changes, as a wikilink ("[[Title]]"); for create kinds, the new file's vault path.
    public var target: String
    public var feature: String
    public var model: String
    public var status: ProposalStatus
    public var citations: [String]
    public var created: String
    public var rationale: String
    public var change: ProposalChange
    /// The strictest AI label of the notes the proposal was made from (taint).
    public var label: AILabel?
    /// Vault path of the proposal file, once written.
    public var path: String?
    public var decided: String?

    public init(kind: ProposalKind, target: String, feature: String, model: String, rationale: String, change: ProposalChange,
                citations: [String] = [], status: ProposalStatus = .open, created: String, label: AILabel? = nil,
                path: String? = nil, decided: String? = nil) {
        self.kind = kind
        self.target = target
        self.feature = feature
        self.model = model
        self.status = status
        self.citations = citations
        self.created = created
        self.rationale = rationale
        self.change = change
        self.label = label
        self.path = path
        self.decided = decided
    }

    /// Kinds that create a new note rather than change an existing one.
    public var createsNote: Bool { kind == .claim || kind == .trail || kind == .decision || kind == .merge && change.removed.isEmpty }

    public func render() -> String {
        var lines = ["---", "type: proposal", "kind: \(kind.rawValue)", "target: \(FrontmatterEditor.yamlScalar(target))",
                     "feature: \(feature)", "origin: ai", "model: \(FrontmatterEditor.yamlScalar(model))",
                     "status: \(status.rawValue)"]
        if let label { lines.append("ai: \(label.rawValue)") }
        let cited = citations.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ", ")
        lines.append("citations: [\(cited)]")
        lines.append("created: \(created)")
        if let decided { lines.append("decided: \(decided)") }
        lines.append("---")
        return lines.joined(separator: "\n") + "\nRationale: \(rationale)\n\n```diff\n\(change.rendered)\n```\n"
    }

    public static func parse(_ text: String, path: String? = nil) -> Proposal? {
        let document = MarkdownDocument(text: text)
        guard let frontmatter = document.frontmatter, frontmatter["type"]?.text == "proposal",
              let kind = frontmatter["kind"]?.text.flatMap(ProposalKind.init(rawValue:)),
              let target = frontmatter["target"]?.text else { return nil }
        let body = document.bodyLines.map(\.text).joined(separator: "\n")
        var rationale = ""
        if let line = body.split(separator: "\n").first(where: { $0.hasPrefix("Rationale:") }) {
            rationale = line.dropFirst("Rationale:".count).trimmingCharacters(in: .whitespaces)
        }
        // The last diff block wins (an edited proposal appends its edited version).
        var change = ProposalChange(added: [])
        var inDiff = false
        var block: [String] = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```diff") { inDiff = true; block = [] } else if inDiff && line.hasPrefix("```") {
                inDiff = false
                change = ProposalChange.parse(block.joined(separator: "\n"))
            } else if inDiff { block.append(String(line)) }
        }
        return Proposal(kind: kind, target: target, feature: frontmatter["feature"]?.text ?? "unknown",
                        model: frontmatter["model"]?.text ?? "unknown", rationale: rationale, change: change,
                        citations: frontmatter["citations"]?.strings ?? [],
                        status: frontmatter["status"]?.text.flatMap(ProposalStatus.init(rawValue:)) ?? .open,
                        created: frontmatter["created"]?.text ?? "",
                        label: frontmatter["ai"]?.text.flatMap(AILabel.init(rawValue:)), path: path,
                        decided: frontmatter["decided"]?.text)
    }

    /// "AI/Proposals/2026-11-09 1432 link Hybrid retrieval.md".
    public static func fileName(kind: ProposalKind, target: String, stamp: String) -> String {
        var name = target.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
        name = String(name.split(separator: "|").first ?? Substring(name))
        name = String(name.split(separator: "/").last ?? Substring(name))
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        let safe = name.map { "/\\:*?\"<>|#^[]".contains($0) ? " " : $0 }
        let stem = String(String(safe).prefix(60)).trimmingCharacters(in: .whitespaces)
        return "AI/Proposals/\(stamp) \(kind.rawValue) \(stem.isEmpty ? "note" : stem).md"
    }
}

public enum ProposalError: Error, Equatable, CustomStringConvertible {
    case conflict(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .conflict(let reason): "the note changed since this was proposed: \(reason)"
        case .invalid(let reason): "invalid proposal: \(reason)"
        }
    }
}

/// What accepting a proposal does to the vault.
public enum ProposalEffect: Sendable, Equatable {
    case modify(text: String)
    case create(path: String, text: String)
}

/// Pure application of a proposal to its target's text.
public enum ProposalApplier {
    public static func apply(_ proposal: Proposal, to target: String?) throws -> ProposalEffect {
        let change = proposal.change
        if proposal.createsNote {
            guard proposal.target.lowercased().hasSuffix(".md"), !proposal.target.contains("[[") else {
                throw ProposalError.invalid("a \(proposal.kind.rawValue) proposal's target must be the new note's path")
            }
            guard target == nil else { throw ProposalError.conflict("\(proposal.target) already exists") }
            return .create(path: proposal.target, text: change.added.joined(separator: "\n") + "\n")
        }
        guard var text = target else { throw ProposalError.conflict("the target note no longer exists") }
        guard !change.added.isEmpty || !change.removed.isEmpty else { throw ProposalError.invalid("empty change") }
        switch proposal.kind {
        case .link:
            return .modify(text: appendUnderHeading("Related", lines: change.added, in: text))
        case .tag:
            return .modify(text: try FrontmatterEditor.addListItems("tags", items: change.added, in: text))
        default:
            if change.removed.isEmpty {
                if !text.hasSuffix("\n") { text += "\n" }
                return .modify(text: text + "\n" + change.added.joined(separator: "\n") + "\n")
            }
            return .modify(text: try replace(change.removed, with: change.added, in: text))
        }
    }

    /// Adds lines at the end of the `## <heading>` section, creating it at the end of the note if needed.
    static func appendUnderHeading(_ heading: String, lines added: [String], in text: String) -> String {
        var lines = Lines.split(text).map(\.text)
        let newline = Lines.preferredTerminator(in: Lines.split(text))
        if let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(heading)" }) {
            var end = start + 1
            while end < lines.count, !lines[end].hasPrefix("#") { end += 1 }
            while end > start + 1, lines[end - 1].trimmingCharacters(in: .whitespaces).isEmpty { end -= 1 }
            lines.insert(contentsOf: added, at: end)
        } else {
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
            lines.append(contentsOf: ["", "## \(heading)"] + added)
        }
        return lines.joined(separator: newline) + newline
    }

    /// Replaces the first exact run of `removed` lines (trailing whitespace ignored) with `added`.
    static func replace(_ removed: [String], with added: [String], in text: String) throws -> String {
        let split = Lines.split(text)
        let lines = split.map(\.text)
        let wanted = removed.map { $0.trimmingTrailingWhitespace() }
        guard let start = (0...(max(0, lines.count - wanted.count))).first(where: { index in
            index + wanted.count <= lines.count
                && zip(lines[index..<(index + wanted.count)], wanted).allSatisfy { $0.trimmingTrailingWhitespace() == $1 }
        }) else {
            throw ProposalError.conflict("couldn't find “\(removed.first ?? "")”")
        }
        var result = lines
        result.replaceSubrange(start..<(start + wanted.count), with: added)
        let newline = Lines.preferredTerminator(in: split)
        return result.joined(separator: newline) + (text.hasSuffix("\n") ? newline : "")
    }
}

extension FrontmatterEditor {
    /// Adds items to a top-level list property (`tags: [a, b]`, a block list, or a missing key),
    /// changing as few lines as possible. Items already present are skipped.
    public static func addListItems(_ key: String, items: [String], in text: String) throws -> String {
        let document = MarkdownDocument(text: text)
        if let error = document.frontmatter?.error { throw InvalidYAML(description: error) }
        let existing = Set((document.frontmatter?[key]?.strings ?? []).map { $0.lowercased() })
        let fresh = items.map { $0.trimmingCharacters(in: .whitespaces).trimmingPrefix("#") }.map(String.init)
            .filter { !$0.isEmpty && !existing.contains($0.lowercased()) }
        guard !fresh.isEmpty else { return text }
        guard document.frontmatter != nil else {
            return try setScalar(key, to: "[\(fresh.joined(separator: ", "))]", in: text).replacingOccurrences(
                of: "\(key): \"[\(fresh.joined(separator: ", "))]\"", with: "\(key): [\(fresh.joined(separator: ", "))]")
        }
        var lines = document.lines
        let fenceEnd = document.bodyStart - 1
        guard let keyIndex = (1..<fenceEnd).first(where: { isTopLevelKey(key, line: lines[$0].text) }) else {
            let inserted = Line(text: "\(key): [\(fresh.joined(separator: ", "))]", index: 1,
                                terminator: Lines.preferredTerminator(in: lines))
            lines.insert(inserted, at: 1)
            return rejoin(lines, bom: text.hasPrefix("\u{FEFF}"))
        }
        let line = lines[keyIndex].text
        let value = line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = value.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
            let combined = (inner.isEmpty ? [] : [inner]) + fresh
            lines[keyIndex] = Line(text: "\(key): [\(combined.joined(separator: ", "))]", index: keyIndex,
                                   terminator: lines[keyIndex].terminator)
        } else if value.isEmpty {
            var end = keyIndex + 1
            var indent = "  "
            while end < fenceEnd, lines[end].text.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                indent = String(lines[end].text.prefix { $0 == " " })
                end += 1
            }
            let terminator = Lines.preferredTerminator(in: lines)
            lines.insert(contentsOf: fresh.map { Line(text: "\(indent)- \($0)", index: 0, terminator: terminator) }, at: end)
        } else {
            lines[keyIndex] = Line(text: "\(key): [\(([value] + fresh).joined(separator: ", "))]", index: keyIndex,
                                   terminator: lines[keyIndex].terminator)
        }
        return rejoin(lines, bom: text.hasPrefix("\u{FEFF}"))
    }

    static func rejoin(_ lines: [Line], bom: Bool) -> String {
        (bom ? "\u{FEFF}" : "") + lines.map { $0.text + $0.terminator }.joined()
    }
}
