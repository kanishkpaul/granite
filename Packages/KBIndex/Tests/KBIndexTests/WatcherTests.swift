import Foundation
import GRDB
import KBCore
import Testing
@testable import KBIndex

/// Collects updates from a running VaultSync so tests can wait for a condition.
actor UpdateLog {
    private(set) var updates: [SyncUpdate] = []
    func add(_ update: SyncUpdate) { updates.append(update) }
    var fullReconciles: Int { updates.filter { if case .fullReconcile = $0.kind { true } else { false } }.count }
    var changedPaths: Set<String> { Set(updates.flatMap(\.paths)) }
}

/// Polls `condition` every 50 ms for up to `seconds`.
func eventually(_ seconds: Double = 5, _ condition: @Sendable () async throws -> Bool) async rethrows -> Bool {
    let deadline = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
    while ContinuousClock.now < deadline {
        if try await condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return try await condition()
}

func paths(_ database: IndexDatabase) throws -> Set<String> {
    Set(try database.pool.read { db in try String.fetchAll(db, sql: "SELECT path FROM objects") })
}

@Suite(.serialized) struct WatcherTests {
    func start(_ temp: TempVault, log: UpdateLog) throws -> (IndexDatabase, Task<Void, any Error>) {
        let database = try IndexDatabase(url: temp.dbURL)
        let sync = VaultSync(indexer: Indexer(database: database, vault: temp.vault, policy: .builtIn), latency: 0.05)
        let task = Task { try await sync.run { await log.add($0) } }
        return (database, task)
    }

    @Test func followsCreateEditDeleteAndRenames() async throws {
        let temp = try TempVault()
        try temp.put("Notes/a.md", "alpha\n")
        let log = UpdateLog()
        let (database, task) = try start(temp, log: log)
        defer { task.cancel() }

        #expect(await eventually { await log.fullReconciles == 1 })
        #expect(try paths(database) == ["Notes/a.md"])

        // FSEvents streams opened "since now" can miss writes made in the first instant.
        try await Task.sleep(for: .milliseconds(300))

        try temp.put("Notes/b.md", "bravo [[a]]\n")
        #expect(try await eventually { try paths(database).contains("Notes/b.md") })
        #expect(try await eventually { try database.backlinks(to: "Notes/a.md").count == 1 })

        try temp.put("Notes/a.md", "alpha edited with quokka\n")
        #expect(try await eventually { try !database.search("quokka").isEmpty })

        try FileManager.default.moveItem(at: temp.root.appending(path: "Notes/b.md"), to: temp.root.appending(path: "Notes/c.md"))
        #expect(try await eventually { try paths(database) == ["Notes/a.md", "Notes/c.md"] })

        try FileManager.default.createDirectory(at: temp.root.appending(path: "Notes/sub"), withIntermediateDirectories: true)
        try temp.put("Notes/sub/d.md", "delta\n")
        #expect(try await eventually { try paths(database).contains("Notes/sub/d.md") })
        try FileManager.default.moveItem(at: temp.root.appending(path: "Notes/sub"), to: temp.root.appending(path: "Archive"))
        #expect(try await eventually { try paths(database) == ["Notes/a.md", "Notes/c.md", "Archive/d.md"] })

        try temp.remove("Notes/a.md")
        #expect(try await eventually { try !paths(database).contains("Notes/a.md") })

        // Hidden folders and non-Markdown files never reach the index.
        try temp.put(".obsidian/workspace.md", "x\n")
        try temp.put("Notes/image.png", "x\n")
        try await Task.sleep(for: .milliseconds(400))
        #expect(await !log.changedPaths.contains(".obsidian/workspace.md"))
        #expect(try !paths(database).contains("Notes/image.png"))
    }

    @Test func replaysChangesMadeWhileStopped() async throws {
        let temp = try TempVault()
        try temp.put("Notes/a.md", "alpha\n")
        do {
            let log = UpdateLog()
            let (_, task) = try start(temp, log: log)
            #expect(await eventually { await log.fullReconciles == 1 })
            try await Task.sleep(for: .milliseconds(300))
            try temp.put("Notes/live.md", "seen live\n")
            #expect(await eventually { await log.changedPaths.contains("Notes/live.md") })
            task.cancel()
            try await Task.sleep(for: .milliseconds(300))
        }

        // granite is "closed": these changes happen with no watcher running.
        try temp.put("Notes/offline.md", "written while closed\n")
        try temp.remove("Notes/a.md")
        try await Task.sleep(for: .milliseconds(300))

        let log = UpdateLog()
        let (database, task) = try start(temp, log: log)
        defer { task.cancel() }
        #expect(try await eventually { try paths(database) == ["Notes/live.md", "Notes/offline.md"] })
        #expect(await log.fullReconciles == 0, "restart should replay from the stored event ID, not walk the vault")
    }

    @Test func mismatchedEventDatabaseForcesReconcile() async throws {
        let temp = try TempVault()
        try temp.put("Notes/a.md", "alpha\n")
        let database = try IndexDatabase(url: temp.dbURL)
        try await database.pool.write { db in
            try db.execute(sql: "INSERT INTO meta(key, value) VALUES ('fsevents.last_event_id', '1'), ('fsevents.database_uuid', 'not-this-volume')")
        }
        try database.pool.close()
        let log = UpdateLog()
        let (reopened, task) = try start(temp, log: log)
        defer { task.cancel() }
        #expect(await eventually { await log.fullReconciles == 1 })
        #expect(try paths(reopened) == ["Notes/a.md"])
    }
}
