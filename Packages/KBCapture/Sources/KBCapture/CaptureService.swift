import Foundation
import KBCore

/// One thing to capture. Only `text` is required (principle 8: zero required fields).
public struct CaptureRequest: Sendable, Hashable {
    public var text: String
    public var url: URL?
    public var title: String?
    public var why: String?

    public init(text: String, url: URL? = nil, title: String? = nil, why: String? = nil) {
        self.text = text
        self.url = url
        self.title = title
        self.why = why
    }
}

public enum CaptureError: Error, Equatable, CustomStringConvertible {
    case emptyText
    case notACapture(String)

    public var description: String {
        switch self {
        case .emptyText: "nothing to capture"
        case .notACapture(let path): "\(path) is not an Inbox capture"
        }
    }
}

/// Writes captures into `Inbox/` through `SafeWriter`. An actor, so two captures in the same
/// minute get distinct file names instead of overwriting each other.
public actor CaptureService {
    public static let folder = "Inbox"
    public let vault: Vault
    let writer: SafeWriter
    let timeZone: TimeZone
    let now: @Sendable () -> Date
    /// Names chosen but not yet on disk. Actors are reentrant: while one capture awaits the
    /// writer, another can run, so the file-exists check alone would hand out the same name twice.
    private var reserved = Set<String>()

    public init(vault: Vault, writer: SafeWriter, timeZone: TimeZone = .current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.vault = vault
        self.writer = writer
        self.timeZone = timeZone
        self.now = now
    }

    /// Saves the capture and returns its vault-relative path.
    @discardableResult
    public func capture(_ request: CaptureRequest) async throws -> String {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CaptureError.emptyText }
        let date = now()
        let path = uniquePath(for: date)
        reserved.insert(path)
        defer { reserved.remove(path) }
        try await writer.write(Self.render(request, text: text, date: date, timeZone: timeZone), to: path, as: .user)
        return path
    }

    /// Adds or replaces the "why I saved this" line on an existing capture.
    public func setWhy(_ why: String, for path: String) async throws {
        let line = why.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        guard !line.isEmpty else { return }
        guard path.hasPrefix(Self.folder + "/") else { throw CaptureError.notACapture(path) }
        let current = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        let updated = try FrontmatterEditor.setScalar("why", to: line, in: current)
        try await writer.write(updated, to: path, as: .user)
    }

    func uniquePath(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let stem = String(format: "%04d-%02d-%02d %02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
        var candidate = "\(Self.folder)/\(stem).md"
        var counter = 2
        while reserved.contains(candidate)
            || FileManager.default.fileExists(atPath: vault.url(for: candidate).path(percentEncoded: false)) {
            candidate = "\(Self.folder)/\(stem)-\(counter).md"
            counter += 1
        }
        return candidate
    }

    static func render(_ request: CaptureRequest, text: String, date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        var lines = [
            "---",
            "id: \(ULID(date: date).string)",
            "type: note",
            "kind: capture",
            "origin: human",
            "created: \(formatter.string(from: date))",
        ]
        if let url = request.url { lines.append("source: \(FrontmatterEditor.yamlScalar(url.absoluteString))") }
        if let why = request.why?.trimmingCharacters(in: .whitespacesAndNewlines), !why.isEmpty {
            lines.append("why: \(FrontmatterEditor.yamlScalar(why.replacingOccurrences(of: "\n", with: " ")))")
        }
        lines.append("---")
        var body = lines.joined(separator: "\n") + "\n"
        if let title = request.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            body += "# \(title.replacingOccurrences(of: "\n", with: " "))\n\n"
        }
        return body + text + "\n"
    }
}
