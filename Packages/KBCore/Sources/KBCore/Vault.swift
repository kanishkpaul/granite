import CryptoKit
import Foundation

/// Stat data for one Markdown file, enough to decide whether it needs re-parsing.
public struct FileStat: Sendable, Hashable {
    public let path: String
    public let mtime: Double
    public let size: Int

    public init(path: String, mtime: Double, size: Int) {
        self.path = path
        self.mtime = mtime
        self.size = size
    }
}

public struct Vault: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// Stable per-vault ID for the Application Support folder: hash of the vault path.
    public var id: String {
        let digest = SHA256.hash(data: Data(root.path(percentEncoded: false).utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// `~/Library/Application Support/granite/<vault-id>/`: where index.sqlite and state.sqlite live.
    public var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "granite/\(id)", directoryHint: .isDirectory)
    }

    public func url(for path: String) -> URL {
        root.appending(path: path, directoryHint: .notDirectory)
    }

    public func relativePath(of url: URL) -> String? {
        let base = root.path(percentEncoded: false)
        let full = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard full.hasPrefix(prefix) else { return nil }
        return String(full.dropFirst(prefix.count))
    }

    /// Every `.md` file in the vault (or under one vault-relative folder), skipping hidden folders
    /// (`.obsidian`, `.git`, `.granite`, `.trash`).
    public func markdownFiles(under folder: String? = nil) -> [FileStat] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        let start = folder.map { root.appending(path: $0, directoryHint: .isDirectory) } ?? root
        guard let enumerator = FileManager.default.enumerator(
            at: start, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        let base = root.path(percentEncoded: false)
        let prefixLength = base.hasSuffix("/") ? base.count : base.count + 1
        var files: [FileStat] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md",
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let full = url.standardizedFileURL.path(percentEncoded: false)
            let path = full.count > prefixLength ? String(full.dropFirst(prefixLength)) : url.lastPathComponent
            files.append(FileStat(
                path: path,
                mtime: values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0,
                size: values.fileSize ?? 0
            ))
        }
        return files
    }
}
