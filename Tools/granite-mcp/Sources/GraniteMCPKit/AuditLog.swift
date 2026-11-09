import Foundation

/// Append-only record of what left the Mac through MCP (master plan §6.5, §6.6):
/// tool, time, and the paths returned. Never note content or query text.
public actor AuditLog {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func record(tool: String, paths: [String], isError: Bool) {
        let entry: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "tool": tool,
            "count": paths.count,
            "paths": paths,
            "error": isError,
        ]
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return
        }
        line.append(0x0A)
        let manager = FileManager.default
        let path = url.path(percentEncoded: false)
        do {
            if !manager.fileExists(atPath: path) {
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                manager.createFile(atPath: path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            FileHandle.standardError.write(Data("granite-mcp: audit write failed: \(error)\n".utf8))
        }
    }
}
