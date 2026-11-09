import Foundation
import GRDB

/// `index.sqlite`: a disposable cache of the vault. Markdown is the truth.
/// A schema change bumps `schemaVersion`; an index with any other version is deleted and rebuilt.
public final class IndexDatabase: Sendable {
    public static let schemaVersion = 2

    public let pool: DatabasePool
    public let url: URL
    /// True when this open created a fresh, empty index (first run or schema bump).
    public let isFresh: Bool

    public enum OpenError: Error, CustomStringConvertible {
        case missing(String)
        case outdated(found: Int, expected: Int)

        public var description: String {
            switch self {
            case .missing(let path):
                "no index at \(path): open the vault in granite or run `granite-cli index` first"
            case .outdated(let found, let expected):
                "index schema v\(found) is out of date (expected v\(expected)): open the vault in granite or run `granite-cli index`"
            }
        }
    }

    /// Opens an existing index without writing to it (for `granite-mcp`). Never creates or rebuilds.
    public init(readOnlyAt url: URL) throws {
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { throw OpenError.missing(path) }
        let version = try Self.storedVersion(path: path)
        guard version == Self.schemaVersion else { throw OpenError.outdated(found: version, expected: Self.schemaVersion) }
        var configuration = Configuration()
        configuration.readonly = true
        self.url = url
        self.pool = try DatabasePool(path: path, configuration: configuration)
        self.isFresh = false
    }

    public init(url: URL) throws {
        self.url = url
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let path = url.path(percentEncoded: false)

        var fresh = !manager.fileExists(atPath: path)
        if !fresh {
            let version = try Self.storedVersion(path: path)
            if version != Self.schemaVersion {
                for suffix in ["", "-wal", "-shm"] { try? manager.removeItem(atPath: path + suffix) }
                fresh = true
            }
        }

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA temp_store = MEMORY")
        }
        pool = try DatabasePool(path: path, configuration: configuration)
        isFresh = fresh
        if fresh {
            try pool.write { db in
                try Self.createSchema(db)
                try db.execute(sql: "PRAGMA user_version = \(Self.schemaVersion)")
            }
        }
    }

    static func storedVersion(path: String) throws -> Int {
        let queue = try DatabaseQueue(path: path)
        defer { try? queue.close() }
        return try queue.read { db in try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0 }
    }

    static func createSchema(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE objects(
          rowid INTEGER PRIMARY KEY,
          id TEXT,
          path TEXT NOT NULL UNIQUE,
          path_key TEXT NOT NULL,
          name_key TEXT NOT NULL,
          type TEXT NOT NULL,
          kind TEXT,
          origin TEXT NOT NULL,
          ai_label TEXT NOT NULL,
          status TEXT,
          title TEXT NOT NULL,
          created TEXT,
          mtime REAL NOT NULL,
          size INTEGER NOT NULL,
          hash BLOB NOT NULL,
          parsed_at REAL NOT NULL,
          yaml_error TEXT
        );
        CREATE INDEX objects_id ON objects(id);
        CREATE INDEX objects_path_key ON objects(path_key);
        CREATE INDEX objects_name_key ON objects(name_key);

        CREATE TABLE aliases(
          obj INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          alias TEXT NOT NULL,
          alias_key TEXT NOT NULL
        );
        CREATE INDEX aliases_obj ON aliases(obj);
        CREATE INDEX aliases_key ON aliases(alias_key);

        CREATE TABLE props(
          obj INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          key TEXT NOT NULL,
          v_text TEXT,
          v_num REAL,
          v_date TEXT
        );
        CREATE INDEX props_obj ON props(obj);
        CREATE INDEX props_key ON props(key, v_text);

        CREATE TABLE tags(
          obj INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          tag TEXT NOT NULL,
          tag_key TEXT NOT NULL
        );
        CREATE INDEX tags_obj ON tags(obj);
        CREATE INDEX tags_key ON tags(tag_key);

        CREATE TABLE links(
          src INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          target_text TEXT NOT NULL,
          target_key TEXT NOT NULL,
          dst INTEGER REFERENCES objects(rowid) ON DELETE SET NULL,
          rel TEXT NOT NULL,
          anchor_heading TEXT,
          anchor_block TEXT,
          alias TEXT,
          is_embed INTEGER NOT NULL DEFAULT 0,
          syntax TEXT NOT NULL,
          line INTEGER NOT NULL
        );
        CREATE INDEX links_src ON links(src);
        CREATE INDEX links_dst ON links(dst);
        CREATE INDEX links_unresolved ON links(target_key) WHERE dst IS NULL;

        CREATE TABLE blocks(
          id INTEGER PRIMARY KEY,
          obj INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          block_id TEXT,
          kind TEXT NOT NULL,
          heading_path TEXT NOT NULL,
          start_line INTEGER NOT NULL,
          end_line INTEGER NOT NULL,
          text TEXT NOT NULL,
          origin TEXT NOT NULL
        );
        CREATE INDEX blocks_obj ON blocks(obj);
        CREATE INDEX blocks_block_id ON blocks(block_id) WHERE block_id IS NOT NULL;

        CREATE VIRTUAL TABLE blocks_fts USING fts5(
          text, heading_path,
          content='blocks', content_rowid='id',
          tokenize='unicode61 remove_diacritics 2'
        );
        CREATE TRIGGER blocks_ai AFTER INSERT ON blocks BEGIN
          INSERT INTO blocks_fts(rowid, text, heading_path) VALUES (new.id, new.text, new.heading_path);
        END;
        CREATE TRIGGER blocks_ad AFTER DELETE ON blocks BEGIN
          INSERT INTO blocks_fts(blocks_fts, rowid, text, heading_path)
            VALUES ('delete', old.id, old.text, old.heading_path);
        END;
        CREATE TRIGGER blocks_au AFTER UPDATE ON blocks BEGIN
          INSERT INTO blocks_fts(blocks_fts, rowid, text, heading_path)
            VALUES ('delete', old.id, old.text, old.heading_path);
          INSERT INTO blocks_fts(rowid, text, heading_path) VALUES (new.id, new.text, new.heading_path);
        END;

        CREATE TABLE chunks(
          id INTEGER PRIMARY KEY,
          obj INTEGER NOT NULL REFERENCES objects(rowid) ON DELETE CASCADE,
          first_block INTEGER NOT NULL,
          last_block INTEGER NOT NULL,
          heading_path TEXT NOT NULL,
          prefix TEXT NOT NULL,
          text TEXT NOT NULL,
          tokens INTEGER NOT NULL
        );
        CREATE INDEX chunks_obj ON chunks(obj);

        -- Normalized float32 vectors; deleted with their chunk, so edited notes re-embed.
        CREATE TABLE chunk_vectors(
          chunk INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
          vector BLOB NOT NULL
        );

        -- One row: the model and chunker the stored vectors came from. A mismatch clears them.
        CREATE TABLE embed_meta(
          id INTEGER PRIMARY KEY CHECK (id = 1),
          model_id TEXT NOT NULL,
          dim INTEGER NOT NULL,
          chunker_version INTEGER NOT NULL
        );

        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
        """)
    }
}
