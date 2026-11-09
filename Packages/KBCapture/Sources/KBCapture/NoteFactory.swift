import Foundation
import KBCore

/// Creates new notes and daily notes through `SafeWriter`. Never overwrites an existing file.
/// An actor with reserved names, like `CaptureService`, so concurrent creates can't collide.
public actor NoteFactory {
    public static let notesFolder = "Notes"
    public static let dailyFolder = "Daily"

    public let vault: Vault
    let writer: SafeWriter
    let timeZone: TimeZone
    let now: @Sendable () -> Date
    private var reserved = Set<String>()

    public init(vault: Vault, writer: SafeWriter, timeZone: TimeZone = .current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.vault = vault
        self.writer = writer
        self.timeZone = timeZone
        self.now = now
    }

    /// Creates `<folder>/<title>.md` (or `<title> 2.md`, … if taken) and returns its path.
    public func createNote(title: String, folder: String = notesFolder, body: String = "") async throws -> String {
        let stem = Self.fileName(for: title)
        var path = "\(folder)/\(stem).md"
        var counter = 2
        while reserved.contains(path) || exists(path) {
            path = "\(folder)/\(stem) \(counter).md"
            counter += 1
        }
        reserved.insert(path)
        defer { reserved.remove(path) }
        let date = now()
        try await writer.write(frontmatter(type: "note", date: date) + body, to: path, as: .user)
        return path
    }

    /// Today's (or `date`'s) daily note, created if missing. Returns its path and whether it was new.
    public func dailyNote(for date: Date? = nil) async throws -> (path: String, created: Bool) {
        let day = date ?? now()
        let path = "\(Self.dailyFolder)/\(Self.dayString(day, timeZone: timeZone)).md"
        if reserved.contains(path) || exists(path) { return (path, false) }
        reserved.insert(path)
        defer { reserved.remove(path) }
        try await writer.write(frontmatter(type: "daily", date: day), to: path, as: .user)
        return (path, true)
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false))
    }

    func frontmatter(type: String, date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return "---\nid: \(ULID(date: date).string)\ntype: \(type)\norigin: human\ncreated: \(formatter.string(from: date))\n---\n"
    }

    /// A title that works as a file name and as an Obsidian link target: no path separators and
    /// none of `# ^ [ ] |` (which break `[[links]]`), no leading dots.
    public static func fileName(for title: String) -> String {
        let forbidden = Set("/\\:*?\"<>|#^[]")
        var cleaned = String(title.map { forbidden.contains($0) || $0.isNewline ? " " : $0 })
        while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = String(cleaned.prefix(120)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    public static func dayString(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
