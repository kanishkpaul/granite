import Foundation
import GRDB
import KBCore

/// What one applied batch did.
public struct SyncUpdate: Sendable {
    public enum Kind: Sendable {
        /// Startup or FSEvents lost track: the whole vault was reconciled.
        case fullReconcile
        /// Specific files or folders changed.
        case incremental
    }

    public let kind: Kind
    /// Vault-relative `.md` paths that were (re)indexed or removed.
    public let paths: [String]
    public let report: ReconcileReport
}

/// Keeps `index.sqlite` current while granite runs, and catches up on launch from the
/// persisted FSEvents event ID instead of walking the whole vault.
public actor VaultSync {
    public let indexer: Indexer
    public let database: IndexDatabase
    public let vault: Vault
    let latency: Double

    static let eventKey = "fsevents.last_event_id"
    static let uuidKey = "fsevents.database_uuid"

    public init(indexer: Indexer, latency: Double = 0.2) {
        self.indexer = indexer
        self.database = indexer.database
        self.vault = indexer.vault
        self.latency = latency
    }

    /// Runs until the calling task is cancelled. `onUpdate` sees every applied batch,
    /// starting with the initial catch-up.
    public func run(onUpdate: @Sendable (SyncUpdate) async -> Void) async throws {
        let uuid = FileWatcher.databaseUUID(for: vault.root)
        let stored = try storedEventID(matching: uuid)
        let since: UInt64
        if let stored {
            since = stored
        } else {
            since = FileWatcher.currentEventID()
            let report = try await indexer.reconcile()
            try persist(eventID: since, uuid: uuid)
            await onUpdate(SyncUpdate(kind: .fullReconcile, paths: [], report: report))
        }
        for await batch in FileWatcher.events(root: vault.root, since: since, latency: latency) {
            let update = try await apply(batch)
            if batch.lastEventID > 0 { try persist(eventID: batch.lastEventID, uuid: uuid) }
            if let update { await onUpdate(update) }
        }
    }

    func apply(_ batch: WatchBatch) async throws -> SyncUpdate? {
        if batch.needsRescan {
            return SyncUpdate(kind: .fullReconcile, paths: [], report: try await indexer.reconcile())
        }
        var files = Set<String>()
        for item in batch.paths {
            if item.isDirectory {
                files.formUnion(try indexedPaths(under: item.path))
                files.formUnion(vault.markdownFiles(under: item.path).map(\.path))
            } else {
                files.insert(item.path)
            }
        }
        guard !files.isEmpty else { return nil }
        let sorted = files.sorted()
        return SyncUpdate(kind: .incremental, paths: sorted, report: try await indexer.update(paths: sorted))
    }

    func indexedPaths(under folder: String) throws -> [String] {
        let prefix = folder.hasSuffix("/") ? folder : folder + "/"
        return try database.pool.read { db in
            try String.fetchAll(db, sql: "SELECT path FROM objects WHERE substr(path, 1, ?) = ?",
                                arguments: [prefix.count, prefix])
        }
    }

    func storedEventID(matching uuid: String?) throws -> UInt64? {
        try database.pool.read { db -> UInt64? in
            guard let uuid,
                  try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [Self.uuidKey]) == uuid,
                  let raw = try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [Self.eventKey])
            else { return nil }
            return UInt64(raw)
        }
    }

    func persist(eventID: UInt64, uuid: String?) throws {
        try database.pool.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)",
                           arguments: [Self.eventKey, String(eventID)])
            try db.execute(sql: "INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)",
                           arguments: [Self.uuidKey, uuid ?? ""])
        }
    }
}
