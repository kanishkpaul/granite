import Foundation
import KBCore

/// What the clipper extracted from a page.
public struct WebClip: Sendable, Equatable, Codable {
    public var title: String
    public var author: String
    public var published: String
    public var site: String
    public var description: String
    public var markdown: String
    public var wordCount: Int

    public init(title: String, author: String = "", published: String = "", site: String = "", description: String = "",
                markdown: String, wordCount: Int = 0) {
        self.title = title
        self.author = author
        self.published = published
        self.site = site
        self.description = description
        self.markdown = markdown
        self.wordCount = wordCount
    }
}

/// Clipped pages are raw sources (master plan §4.3, §6.6): `Clippings/<title>.md`, `trust: untrusted`,
/// so every model sees their text as data, and nothing in them can link into the vault.
public enum ClippingNote {
    public static let folder = "Clippings"

    static let invisible = try? NSRegularExpression(pattern: "[\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF\\u00AD]")

    /// Same rules as the in-page sanitizer, applied again on this side (never trust one layer).
    public static func sanitize(_ text: String) -> String {
        var output = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        if let invisible { output = invisible.stringByReplacingMatches(in: output, range: NSRange(output.startIndex..., in: output), withTemplate: "") }
        output = output.replacingOccurrences(of: "[[", with: "[\\[")
        // A clipping can't smuggle in frontmatter or end ours early.
        return output.replacingOccurrences(of: "\n---\n", with: "\n\\---\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func render(_ clip: WebClip, url: URL, clipped: String, why: String? = nil) -> String {
        var lines = ["---", "type: clipping", "origin: source", "trust: untrusted",
                     "title: \(FrontmatterEditor.yamlScalar(sanitize(clip.title)))", "source: \(FrontmatterEditor.yamlScalar(url.absoluteString))"]
        if !clip.author.isEmpty { lines.append("author: \(FrontmatterEditor.yamlScalar(sanitize(clip.author)))") }
        if !clip.published.isEmpty { lines.append("published: \(FrontmatterEditor.yamlScalar(clip.published))") }
        if !clip.site.isEmpty { lines.append("site: \(FrontmatterEditor.yamlScalar(sanitize(clip.site)))") }
        lines.append("clipped: \(clipped)")
        if let why, !why.isEmpty { lines.append("why: \(FrontmatterEditor.yamlScalar(why))") }
        lines += ["---", "# \(sanitize(clip.title))", ""]
        if !clip.description.isEmpty { lines += ["> " + sanitize(clip.description).replacingOccurrences(of: "\n", with: " "), ""] }
        lines += [sanitize(clip.markdown), ""]
        return lines.joined(separator: "\n")
    }

    public static func fileName(for clip: WebClip, url: URL) -> String {
        let title = clip.title.trimmingCharacters(in: .whitespaces)
        return NoteFactory.fileName(for: title.isEmpty ? (url.host ?? "Clipping") : String(title.prefix(100)))
    }
}
