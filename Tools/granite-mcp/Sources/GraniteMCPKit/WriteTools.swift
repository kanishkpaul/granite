import Foundation
import GRDB
import KBCore
import KBIndex
import MCP

/// The tools that write (master plan §6.5): `propose_change` only ever writes a proposal file the
/// user decides on; `create_derived_note` only writes new files under `AI/`, stamped `origin: ai`.
/// Neither can touch your notes. `get_claims` reads the belief ledger.
extension GraniteTools {
    static let writeDefinitions: [Tool] = [
        Tool(
            name: "propose_change",
            description: """
                Propose a change to one of the user's notes. Nothing changes until the user accepts it in granite's \
                proposal queue. `diff` is lines starting with "+ " (add) and "- " (remove, must match the note exactly). \
                Kinds: link (adds lines under "## Related"), edit (replaces the "-" lines), tag (frontmatter tags), \
                prompt or rule (appends), claim (creates the note at `target`, a new path). Cite the notes you relied on.
                """,
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "target": .object(["type": "string", "description": "The note to change, as [[Title]] or a vault path; for claim, the new file's path."]),
                    "kind": .object(["type": "string", "enum": .array(["link", "edit", "tag", "prompt", "rule", "claim"])]),
                    "diff": .object(["type": "string", "description": "Lines starting with '+ ' or '- '."]),
                    "rationale": .object(["type": "string", "description": "One or two sentences: why."]),
                    "citations": .object(["type": "array", "items": .object(["type": "string"]),
                                          "description": "Citations from search results, e.g. [[Note#^block]]."]),
                ]),
                "required": .array(["target", "kind", "diff", "rationale"]),
            ]),
            annotations: .init(title: "Propose a change", readOnlyHint: false, destructiveHint: false, idempotentHint: false,
                               openWorldHint: false)
        ),
        Tool(
            name: "create_derived_note",
            description: """
                Write a new note under AI/ (a synthesis, summary or analysis), stamped origin: ai with its sources. \
                It never overwrites and can't write anywhere else. Every source must be a note you can see.
                """,
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "path": .object(["type": "string", "description": "A new path under AI/, e.g. AI/Synthesis/Retrieval.md."]),
                    "body": .object(["type": "string", "description": "Markdown body. Cite notes inline as [[Note#^block]]."]),
                    "sources": .object(["type": "array", "items": .object(["type": "string"]), "description": "Notes it derives from."]),
                ]),
                "required": .array(["path", "body", "sources"]),
            ]),
            annotations: .init(title: "Create AI note", readOnlyHint: false, destructiveHint: false, idempotentHint: false,
                               openWorldHint: false)
        ),
    ]

    static let claimsDefinition = Tool(
        name: "get_claims",
        description: "The user's claim ledger: assertions they hold, with status, confidence and as_of. Filter by topic words or status.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "topic": .object(["type": "string", "description": "Words to match in the claim or its tags."]),
                "status": .object(["type": "string", "enum": .array(["held", "proposed", "revised", "superseded", "retired"])]),
                "limit": .object(["type": "integer", "description": "Maximum claims (1-100, default 30)."]),
            ]),
        ]),
        annotations: .init(title: "Claims", readOnlyHint: true, openWorldHint: false)
    )

    /// Folders granite manages itself under AI/.
    static let reservedAI = ["AI/Proposals/", "AI/Digests/", "AI/Metrics/", "AI/log.md"]

    func getClaims(_ arguments: [String: Value]) throws -> (CallTool.Result, [String]) {
        let limit = Self.clamp(arguments["limit"]?.intValue, default: 30, max: 100)
        let status = arguments["status"]?.stringValue
        let words = (arguments["topic"]?.stringValue ?? "").lowercased().split(separator: " ").map(String.init)
        let rows = try database.pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT o.path, o.title, o.status, o.ai_label,
                  (SELECT v_num FROM props WHERE obj = o.rowid AND key = 'confidence' LIMIT 1) AS confidence,
                  (SELECT coalesce(v_date, v_text) FROM props WHERE obj = o.rowid AND key = 'as_of' LIMIT 1) AS as_of,
                  (SELECT group_concat(tag, ' ') FROM tags WHERE obj = o.rowid) AS tags
                FROM objects o WHERE o.type = 'claim' ORDER BY as_of DESC
                """).map { row -> (String, String, String?, String, Double?, String?, String) in
                    (row["path"], row["title"], row["status"], row["ai_label"], row["confidence"], row["as_of"], row["tags"] ?? "")
                }
        }
        var lines: [String] = []
        var paths: [String] = []
        for (path, title, claimStatus, label, confidence, asOf, tags) in rows where isVisible(path: path, label: label) {
            if let status, claimStatus != status { continue }
            let haystack = (title + " " + tags).lowercased()
            if !words.allSatisfy({ haystack.contains($0) }) { continue }
            paths.append(path)
            lines.append("- \(title) | status: \(claimStatus ?? "held") | confidence: \(confidence.map { String(format: "%.2f", $0) } ?? "?")"
                         + " | as_of: \(asOf ?? "?") | path: \(path)")
            if lines.count == limit { break }
        }
        return (CallTool.Result(content: [Self.text(lines.isEmpty ? "No matching claims." : lines.joined(separator: "\n"))]), paths)
    }

    func proposeChange(_ arguments: [String: Value]) async throws -> (CallTool.Result, [String]) {
        guard let writer, allowWrites else { throw ToolError(description: "this granite-mcp is read-only") }
        guard let target = arguments["target"]?.stringValue?.trimmingCharacters(in: .whitespaces), !target.isEmpty,
              let kind = arguments["kind"]?.stringValue.flatMap(ProposalKind.init(rawValue:)),
              ["link", "edit", "tag", "prompt", "rule", "claim"].contains(kind.rawValue),
              let diff = arguments["diff"]?.stringValue, let rationale = arguments["rationale"]?.stringValue,
              !rationale.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ToolError(description: "propose_change needs target, kind (link|edit|tag|prompt|rule|claim), diff and rationale")
        }
        let change = ProposalChange.parse(diff)
        guard !change.added.isEmpty || !change.removed.isEmpty else { throw ToolError(description: "the diff has no '+ ' or '- ' lines") }
        let citations = (arguments["citations"]?.arrayValue ?? []).compactMap(\.stringValue).prefix(20).map { $0 }
        var proposal = Proposal(kind: kind, target: target, feature: "mcp", model: "mcp client", rationale: rationale,
                                change: change, citations: Array(citations), created: "", label: .cloud)
        var touched: [String]
        if proposal.createsNote {
            let path = Self.normalize(target)
            guard path.lowercased().hasSuffix(".md"), !path.hasPrefix("AI/"), (try? SafeWriter.validatePath(path)) != nil,
                  isVisible(path: path, label: policy.policy(for: path).ai.rawValue) else {
                throw ToolError(description: "a claim needs a new .md path in a folder you can see (not AI/)")
            }
            guard !FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) else {
                throw ToolError(description: "\(path) already exists")
            }
            proposal.target = path
            touched = [path]
        } else {
            let link = target.hasPrefix("[[") ? String(target.dropFirst(2).dropLast(2)) : Self.normalize(target)
            let key = String(link.split(separator: "|").first ?? "").split(separator: "#").first.map(String.init) ?? link
            guard let path = try database.resolve(linkTarget: key, from: ""), let note = try database.note(path: path),
                  isVisible(path: note.path, label: note.aiLabel), !note.path.hasPrefix("AI/") else {
                throw ToolError(description: "no visible note \(target) to propose a change to")
            }
            // Check now, so the agent learns about a mismatch instead of the user at accept time.
            let text = try String(contentsOf: vault.url(for: note.path), encoding: .utf8)
            do {
                _ = try ProposalApplier.apply(proposal, to: text)
            } catch {
                throw ToolError(description: "the change doesn't apply to \(note.path): \(error)")
            }
            proposal.target = "[[\(String(note.path.dropLast(3)))]]"
            touched = [note.path]
        }
        do {
            let path = try await ProposalFiles.write(proposal, vault: vault, writer: writer)
            touched.append(path)
            return (CallTool.Result(content: [Self.text("Proposed in \(path). Nothing changes until the user accepts it in granite.")]),
                    touched)
        } catch let error as ProposalStoreError {
            throw ToolError(description: error.description)
        }
    }

    func createDerivedNote(_ arguments: [String: Value]) async throws -> (CallTool.Result, [String]) {
        guard let writer, allowWrites else { throw ToolError(description: "this granite-mcp is read-only") }
        guard let rawPath = arguments["path"]?.stringValue, let body = arguments["body"]?.stringValue,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError(description: "create_derived_note needs path, body and sources")
        }
        let path = Self.normalize(rawPath)
        guard path.hasPrefix("AI/"), path.lowercased().hasSuffix(".md"), !Self.reservedAI.contains(where: { path.hasPrefix($0) }),
              (try? writer.validate(path, role: .ai)) != nil else {
            throw ToolError(description: "the path must be a new .md file under AI/ (not AI/Proposals, AI/Digests or AI/Metrics)")
        }
        guard !FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) else {
            throw ToolError(description: "\(path) already exists; AI notes are never overwritten (write a new one)")
        }
        let sources = (arguments["sources"]?.arrayValue ?? []).compactMap(\.stringValue)
        guard !sources.isEmpty else { throw ToolError(description: "list the notes this derives from in sources") }
        var links: [String] = []
        var touched: [String] = []
        for source in sources.prefix(50) {
            let inner = source.hasPrefix("[[") ? String(source.dropFirst(2).dropLast(2)) : source
            let key = String(inner.split(separator: "|").first ?? "").split(separator: "#").first.map(String.init) ?? inner
            guard let resolved = try database.resolve(linkTarget: key, from: ""), let note = try database.note(path: resolved),
                  isVisible(path: note.path, label: note.aiLabel) else {
                throw ToolError(description: "source \(source) is not a note you can see")
            }
            links.append(source.hasPrefix("[[") ? source : "[[\(String(note.path.dropLast(3)))]]")
            touched.append(note.path)
        }
        let quoted = links.map { "\"\($0.replacingOccurrences(of: "\"", with: "'"))\"" }.joined(separator: ", ")
        let text = ["---", "type: synthesis", "origin: ai", "model: \"mcp client\"", "ai: cloud", "sources: [\(quoted)]",
                    "derived_from: [\(quoted)]", "created: \(ProposalStore.day(Date(), .current))", "---",
                    body.trimmingCharacters(in: .whitespacesAndNewlines), ""].joined(separator: "\n")
        try await writer.write(text, to: path, as: .ai)
        return (CallTool.Result(content: [Self.text("Wrote \(path) (origin: ai). It stays out of the user's evidence unless they include AI notes.")]),
                touched + [path])
    }
}

extension SafeWriter {
    /// Path rules without a writer instance (no `..`, no `.git`, no absolute paths).
    static func validatePath(_ path: String) throws -> String {
        try SafeWriter(vault: Vault(root: URL(filePath: "/"))).validate(path, role: .user)
    }
}
