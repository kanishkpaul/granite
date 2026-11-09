import Foundation
import GRDB

/// A vault folder and how many indexed notes it holds (including subfolders).
public struct FolderInfo: Sendable, Hashable, Identifiable {
    /// Vault-relative, no trailing slash.
    public let path: String
    public let noteCount: Int

    public var id: String { path }
    public var name: String { path.split(separator: "/").last.map(String.init) ?? path }
    public var depth: Int { path.split(separator: "/").count - 1 }
}

extension IndexDatabase {
    /// Every folder that contains notes, with recursive counts, sorted by path.
    public func folders() throws -> [FolderInfo] {
        let paths = try pool.read { db in try String.fetchAll(db, sql: "SELECT path FROM objects") }
        var counts: [String: Int] = [:]
        for path in paths {
            var parts = path.split(separator: "/").dropLast()
            while !parts.isEmpty {
                counts[parts.joined(separator: "/"), default: 0] += 1
                parts = parts.dropLast()
            }
        }
        return counts.map { FolderInfo(path: $0.key, noteCount: $0.value) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Notes in a folder (and its subfolders), newest first. `""` means the whole vault.
    public func notes(inFolder folder: String, limit: Int = 500, offset: Int = 0) throws -> [NoteRecord] {
        let prefix = folder.isEmpty ? "" : (folder.hasSuffix("/") ? folder : folder + "/")
        return try pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT path, id, title, type, origin, ai_label, mtime FROM objects
                WHERE substr(path, 1, ?) = ? ORDER BY mtime DESC, path LIMIT ? OFFSET ?
                """, arguments: [prefix.count, prefix, limit, offset])
            .map { NoteRecord(path: $0["path"], id: $0["id"], title: $0["title"], type: $0["type"], origin: $0["origin"],
                              aiLabel: $0["ai_label"], mtime: $0["mtime"]) }
        }
    }
}

extension IndexDatabase {
    /// Tags starting with `prefix` (case-insensitive), most used first: for `#` completion.
    public func tags(matching prefix: String, limit: Int = 20) throws -> [(tag: String, count: Int)] {
        let key = prefix.lowercased()
        return try pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT min(tag) AS tag, count(*) AS n FROM tags
                WHERE substr(tag_key, 1, ?) = ? GROUP BY tag_key ORDER BY n DESC, tag LIMIT ?
                """, arguments: [key.count, key, limit])
            .map { (tag: $0["tag"], count: $0["n"]) }
        }
    }
}
