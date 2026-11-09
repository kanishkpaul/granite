import CryptoKit
import Foundation

/// Everything the index needs from one Markdown file.
public struct ParsedNote: Sendable {
    /// Vault-relative path with "/" separators.
    public let path: String
    /// File name without ".md": Obsidian's link target and display name.
    public let title: String
    /// Frontmatter `id`, if present. granite stamps it lazily (master plan §4.5).
    public let id: String?
    public let type: ObjectType
    public let kind: String?
    public let origin: Origin
    /// Strictest of the folder label and the note's own `ai:` property.
    public let aiLabel: AILabel
    public let status: String?
    public let created: String?
    public let aliases: [String]
    public let frontmatter: Frontmatter?
    /// Unique tags without "#", in first-seen order.
    public let tags: [String]
    /// Inline links, embeds and typed frontmatter relations.
    public let links: [LinkRef]
    public let blocks: [Block]
    public let size: Int
    /// SHA-256 of the file bytes.
    public let hash: Data
}

public enum NoteParser {
    public static func parse(data: Data, path: String, policy: VaultPolicy) -> ParsedNote {
        let text = String(decoding: data, as: UTF8.self)
        let document = MarkdownDocument(text: text)
        let folder = policy.policy(for: path)
        let frontmatter = document.frontmatter
        let body = BlockParser.scan(document.bodyLines)

        let title = Self.title(for: path)
        let declaredType = frontmatter?["type"]?.text.flatMap(ObjectType.init(rawValue:))
        let type = declaredType ?? inferType(path: path)

        // A folder whose origin is `ai` cannot be laundered into human text by a property.
        let declaredOrigin = frontmatter?["origin"]?.text.flatMap(Origin.init(rawValue:))
        let origin = folder.origin == .ai ? .ai : (declaredOrigin ?? folder.origin)

        let declaredLabel = frontmatter?["ai"]?.text.flatMap(AILabel.init(rawValue:))
        let aiLabel = AILabel.strictest([folder.ai] + (declaredLabel.map { [$0] } ?? [])) ?? folder.ai

        var links = body.links
        for relation in Relation.allCases {
            guard let value = frontmatter?[relation.rawValue] else { continue }
            for item in value.strings {
                links.append(contentsOf: frontmatterLinks(item, relation: relation.rawValue))
            }
        }
        links = links.map { resolveRelative($0, from: path) }

        var seen = Set<String>()
        var tags: [String] = []
        let declaredTags = (frontmatter?["tags"]?.strings ?? []) + (frontmatter?["tag"]?.strings ?? [])
        for raw in declaredTags.flatMap({ $0.split(whereSeparator: { $0 == "," || $0 == " " }) }) + body.tags.map({ Substring($0) }) {
            var tag = String(raw)
            while tag.hasPrefix("#") { tag.removeFirst() }
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { continue }
            tags.append(tag)
        }

        let aliases = (frontmatter?["aliases"]?.strings ?? []) + (frontmatter?["alias"]?.strings ?? [])

        return ParsedNote(
            path: path,
            title: title,
            id: frontmatter?["id"]?.text.flatMap { $0.isEmpty ? nil : $0 },
            type: type,
            kind: frontmatter?["kind"]?.text,
            origin: origin,
            aiLabel: aiLabel,
            status: frontmatter?["status"]?.text,
            created: frontmatter?["created"]?.text,
            aliases: aliases,
            frontmatter: frontmatter,
            tags: tags,
            links: links,
            blocks: body.blocks,
            size: data.count,
            hash: Data(SHA256.hash(data: data))
        )
    }

    public static func title(for path: String) -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return name.lowercased().hasSuffix(".md") ? String(name.dropLast(3)) : name
    }

    static func inferType(path: String) -> ObjectType {
        let lowered = path.lowercased()
        let rules: [(String, ObjectType)] = [
            ("daily/", .daily), ("clippings/", .clipping), ("papers/", .source), ("projects/", .project),
            ("ai/proposals/", .proposal), ("ai/digests/", .digest), ("ai/", .synthesis),
        ]
        return rules.first { lowered.hasPrefix($0.0) }?.1 ?? .note
    }

    /// A frontmatter relation item is a quoted wikilink ("[[Target#^id]]") or a bare name.
    static func frontmatterLinks(_ item: String, relation: String) -> [LinkRef] {
        let found = InlineScanner.scan(item, line: 0).links
        if !found.isEmpty {
            return found.map {
                LinkRef(target: $0.target, heading: $0.heading, blockID: $0.blockID, alias: $0.alias,
                        isEmbed: false, syntax: $0.syntax, relation: relation, line: 0)
            }
        }
        let trimmed = item.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("://") else { return [] }
        return [LinkRef.parseWikilink(trimmed, isEmbed: false, relation: relation, line: 0)]
    }

    /// Markdown links are relative to the note's folder; rewrite them to vault-relative paths.
    static func resolveRelative(_ link: LinkRef, from path: String) -> LinkRef {
        guard link.syntax == .markdown, !link.target.isEmpty else { return link }
        var components = path.split(separator: "/").dropLast().map(String.init)
        for part in link.target.split(separator: "/") {
            switch part {
            case ".": continue
            case "..": if !components.isEmpty { components.removeLast() }
            default: components.append(String(part))
            }
        }
        return LinkRef(target: components.joined(separator: "/"), heading: link.heading, blockID: link.blockID,
                       alias: link.alias, isEmbed: link.isEmbed, syntax: link.syntax, relation: link.relation,
                       line: link.line)
    }
}
