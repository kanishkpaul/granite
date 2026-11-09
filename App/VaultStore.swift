import CryptoKit
import KBAI
import KBCapture
import KBCore
import KBIndex
import SwiftUI

@MainActor
@Observable
final class VaultStore {
    private(set) var vault: Vault?
    private(set) var status = "Open a vault folder to index it."
    private(set) var hits: [SearchHit] = []
    private(set) var isIndexing = false
    private(set) var openPath: String?
    let editor = EditorController()

    private var database: IndexDatabase?
    private var indexer: Indexer?
    private var writer: SafeWriter?
    private var searchTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var loadedVersion = 0
    /// Hash of the open note's text as the editor last saw it; external edits differ from it.
    private var editorHash: Data?
    private var cursor = 0
    private(set) var captureService: CaptureService?
    private(set) var noteFactory: NoteFactory?
    private var renamer: RenameService?
    private var inbox: InboxQueue?
    private(set) var inboxItems: [InboxItem] = []
    /// `state.sqlite`: audit log, feature events, search and Q&A logs, metrics.
    private(set) var state: StateDatabase?
    /// Every model call goes through this (routing, labels, budget, audit).
    private(set) var models: ModelService?
    private var policy = VaultPolicy.builtIn
    var budget: Budget { policy.budget ?? .standard }

    // MARK: Shell state
    enum SidebarItem: Hashable {
        case inbox
        case all
        case folder(String)

        var folder: String {
            switch self {
            case .inbox: "Inbox"
            case .all: ""
            case .folder(let path): path
            }
        }
    }

    var selection: SidebarItem? = .inbox {
        didSet { refreshList() }
    }
    private(set) var folders: [FolderInfo] = []
    private(set) var listed: [NoteRecord] = []
    private(set) var inboxCount = 0
    private(set) var inspector: InspectorData?
    /// Hooks for app-level services (auto-commit) that follow the vault.
    var onVaultOpened: ((URL) -> Void)?
    var onVaultChanged: (() -> Void)?

    static let vaultKey = "granite.vaultPath"

    init() {
        editor.addListener { [weak self] message in self?.handle(message) }
    }

    /// Reopens the vault from the last session, if it still exists.
    func reopenLastVault() async {
        guard vault == nil, let path = UserDefaults.standard.string(forKey: Self.vaultKey) else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        await open(URL(filePath: path, directoryHint: .isDirectory))
    }

    func open(_ url: URL) async {
        let vault = Vault(root: url)
        self.vault = vault
        UserDefaults.standard.set(vault.root.path(percentEncoded: false), forKey: Self.vaultKey)
        let writer = SafeWriter(vault: vault)
        self.writer = writer
        // Capture works as soon as a vault is known: it needs no index.
        captureService = CaptureService(vault: vault, writer: writer)
        noteFactory = NoteFactory(vault: vault, writer: writer)
        onVaultOpened?(vault.root)
        isIndexing = true
        status = "Indexing \(url.lastPathComponent)…"
        syncTask?.cancel()
        do {
            let policy = try VaultPolicy.load(vaultRoot: vault.root)
            self.policy = policy
            let state = try StateDatabase(url: vault.supportDirectory.appending(path: "state.sqlite"))
            self.state = state
            models = ModelService(providers: ModelService.standardProviders(), state: state,
                                  budget: policy.budget ?? .standard)
            let database = try IndexDatabase(url: vault.supportDirectory.appending(path: "index.sqlite"))
            let indexer = Indexer(database: database, vault: vault, policy: policy)
            self.database = database
            self.indexer = indexer
            let renamer = RenameService(indexer: indexer, writer: writer)
            self.renamer = renamer
            inbox = InboxQueue(indexer: indexer, writer: writer, renamer: renamer)
            // An existing index is usable right away; the watcher then replays only what changed
            // while granite was closed, which may be nothing (so no update would arrive).
            if !database.isFresh {
                isIndexing = false
                status = "\(url.lastPathComponent): \((try? database.stats().objects) ?? 0) notes"
                refreshLists()
            }
            // Catches up from the last FSEvents ID (or reconciles), then follows every change.
            let sync = VaultSync(indexer: indexer)
            // The store lives as long as the app; the task is cancelled when another vault opens.
            syncTask = Task {
                do {
                    try await sync.run { update in await self.applied(update) }
                } catch {
                    syncFailed(error)
                }
            }
        } catch {
            isIndexing = false
            status = "Indexing failed: \(error)"
        }
    }

    private func applied(_ update: SyncUpdate) {
        isIndexing = false
        refreshLists()
        refreshInspector()
        if update.kind == .fullReconcile || !update.paths.isEmpty { onVaultChanged?() }
        status = update.kind == .fullReconcile ? update.report.description : "Updated \(update.paths.count) note(s)"
        if let path = openPath, update.kind == .fullReconcile || update.paths.contains(path) {
            reloadIfChangedOnDisk(path)
        }
    }

    private func syncFailed(_ error: any Error) {
        isIndexing = false
        status = "File watching stopped: \(error)"
    }

    /// Another program changed the open note: show its version. (Phase 1 adds a keep-mine /
    /// take-theirs banner when the editor also has unsaved changes.)
    private func reloadIfChangedOnDisk(_ path: String) {
        guard let vault else { return }
        guard let data = try? Data(contentsOf: vault.url(for: path)) else {
            status = "\(path) was deleted or moved on disk"
            return
        }
        let hash = Data(SHA256.hash(data: data))
        guard hash != editorHash else { return }
        editorHash = hash
        // The editor applies it as a minimal edit (cursor and undo kept), or asks if it has unsaved edits.
        editor.send(.external(path: path, text: String(decoding: data, as: UTF8.self)))
        sendResolved(for: path)
        status = "\(path) changed on disk"
    }

    /// Debounced full-text search; the query runs off the main actor.
    func search(_ text: String) {
        searchTask?.cancel()
        guard let database, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            hits = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) { try? database.search(text) }.value
            guard !Task.isCancelled else { return }
            hits = result ?? []
        }
    }

    struct NoVaultError: LocalizedError {
        var errorDescription: String? { "Open a vault in granite first." }
    }

    /// Saves a capture to `Inbox/` and returns its path.
    func capture(_ request: CaptureRequest) async throws -> String {
        guard let captureService else { throw NoVaultError() }
        let path = try await captureService.capture(request)
        status = "Captured \(path)"
        return path
    }

    func setWhy(_ why: String, for path: String) async throws {
        guard let captureService else { throw NoVaultError() }
        try await captureService.setWhy(why, for: path)
    }

    func openNote(id: String) {
        guard let database, let record = try? database.note(id: id) else {
            status = "No note with id \(id)"
            return
        }
        openNote(record.path)
    }

    func openNote(_ path: String, line: Int? = nil) {
        guard let vault else { return }
        do {
            let data = try Data(contentsOf: vault.url(for: path))
            let text = String(decoding: data, as: UTF8.self)
            loadedVersion += 1
            openPath = path
            editorHash = Data(SHA256.hash(data: data))
            var cursor = 0
            if let line, line > 1 {
                cursor = text.split(separator: "\n", maxSplits: line - 1, omittingEmptySubsequences: false)
                    .prefix(line - 1).reduce(0) { $0 + $1.utf16.count + 1 }
            }
            editor.send(.load(path: path, text: text, version: loadedVersion, cursor: cursor))
            sendResolved(for: path)
            refreshInspector()
        } catch {
            status = "Could not open \(path): \(error.localizedDescription)"
        }
    }

    private func sendResolved(for path: String) {
        guard let database else { return }
        if let targets = try? database.resolvedTargets(from: path) { editor.send(.setResolved(targets: targets)) }
    }

    private func handle(_ message: EditorMessage) {
        switch message {
        case .changed(let version, let text):
            guard let path = openPath, version > loadedVersion else { return }
            loadedVersion = version
            editorHash = Data(SHA256.hash(data: Data(text.utf8)))
            Task { await save(text, to: path) }
        case .selection(_, let head, _):
            cursor = head
        case .complete(let id, let kind, let query):
            editor.send(.completions(id: id, items: completions(kind: kind, query: query)))
        case .resolveEmbed(let id, let target):
            editor.send(.embed(embedContent(id: id, target: target)))
        case .openLink(let target, _, _, _):
            guard let from = openPath, let database else { return }
            if let path = try? database.resolve(linkTarget: target, from: from) {
                openNote(path)
            } else {
                status = "No note named “\(target)” yet."
            }
        default:
            break
        }
    }

    private func save(_ text: String, to path: String) async {
        guard let writer, let indexer else { return }
        do {
            try await writer.write(text, to: path, as: .user)
            _ = try await indexer.update(paths: [path])  // the watcher's echo is then a cheap hash match
            if openPath == path { sendResolved(for: path) }
            status = "Saved \(path)"
        } catch {
            status = "Save failed: \(error)"
        }
    }

    // MARK: Shell

    func refreshLists() {
        guard let database else { return }
        folders = (try? database.folders()) ?? []
        inboxCount = folders.first { $0.path == "Inbox" }?.noteCount ?? 0
        refreshList()
        Task { await refreshInbox() }
    }

    func refreshInbox() async {
        inboxItems = await inbox?.items() ?? []
    }

    // MARK: Inbox decisions, rename, move

    private func afterMove(from old: String, to new: String) async {
        refreshLists()
        await refreshInbox()
        if openPath == old { openNote(new) }
    }

    func inboxMakeNote(_ item: InboxItem, title: String) async {
        guard let inbox else { return }
        do {
            let path = try await inbox.makeNote(item.path, title: title)
            status = "Made \(path)"
            await afterMove(from: item.path, to: path)
        } catch {
            status = "Could not make a note: \(error)"
        }
    }

    func inboxAppend(_ item: InboxItem, to note: String) async {
        guard let inbox else { return }
        do {
            try await inbox.append(item.path, to: note)
            status = "Appended to \(note)"
            await afterMove(from: item.path, to: note)
        } catch {
            status = "Could not append: \(error)"
        }
    }

    func inboxArchive(_ item: InboxItem) async {
        guard let inbox else { return }
        do {
            let path = try await inbox.archive(item.path)
            status = "Archived to \(path)"
            await afterMove(from: item.path, to: path)
        } catch {
            status = "Could not archive: \(error)"
        }
    }

    func inboxBankruptcy() async {
        guard let inbox else { return }
        do {
            let archived = try await inbox.bankruptcy()
            status = "Archived \(archived.count) old captures"
            refreshLists()
            await refreshInbox()
        } catch {
            status = "Bankruptcy failed: \(error)"
        }
    }

    /// Renames the open note in place; every link to it is rewritten.
    func renameOpenNote(to title: String) async {
        guard let path = openPath else { return }
        let folder = Self.folder(of: path)
        let stem = NoteFactory.fileName(for: title)
        await move(path, to: folder.isEmpty ? "\(stem).md" : "\(folder)/\(stem).md")
    }

    /// Moves the open note to another folder, keeping its name; links are rewritten where needed.
    func moveOpenNote(toFolder folder: String) async {
        guard let path = openPath else { return }
        let name = (path as NSString).lastPathComponent
        await move(path, to: folder.isEmpty ? name : "\(folder)/\(name)")
    }

    private func move(_ path: String, to destination: String) async {
        guard let renamer, destination != path else { return }
        do {
            // Save pending edits first so the moved file has them.
            let report = try await renamer.rename(from: path, to: destination)
            status = "Moved to \(destination); rewrote \(report.rewrittenLinks) link(s) in \(report.rewrittenFiles.count) note(s)"
            await afterMove(from: path, to: destination)
        } catch {
            status = "Could not move: \(error)"
        }
    }

    private func refreshList() {
        guard let database, let selection else {
            listed = []
            return
        }
        listed = (try? database.notes(inFolder: selection.folder, limit: 500)) ?? []
    }

    func refreshInspector() {
        guard let path = openPath, let vault, let data = try? Data(contentsOf: vault.url(for: path)) else {
            inspector = nil
            return
        }
        let note = NoteParser.parse(data: data, path: path, policy: policy)
        let backlinks = (try? database?.backlinks(to: path)) ?? []
        inspector = InspectorData(note: note, backlinks: backlinks)
    }

    func recentNotes(limit: Int = 20) -> [NoteRecord] {
        (try? database?.recent(limit: limit)) ?? []
    }

    func titles(matching text: String, limit: Int = 30) -> [NoteSummary] {
        (try? database?.titles(matching: text, limit: limit)) ?? []
    }

    /// ⌘N / switcher "Create": a new note in Notes/, indexed and opened.
    func newNote(title: String) async {
        guard let noteFactory else { return }
        do {
            let path = try await noteFactory.createNote(title: title)
            _ = try await indexer?.update(paths: [path])
            refreshLists()
            openNote(path)
        } catch {
            status = "Could not create note: \(error)"
        }
    }

    /// ⌘D: today's daily note, created if missing.
    func openToday() async {
        guard let noteFactory else { return }
        do {
            let (path, created) = try await noteFactory.dailyNote()
            if created {
                _ = try await indexer?.update(paths: [path])
                refreshLists()
            }
            openNote(path)
        } catch {
            status = "Could not open today's note: \(error)"
        }
    }

    func revealInFinder() {
        guard let path = openPath, let vault else { return }
        NSWorkspace.shared.activateFileViewerSelecting([vault.url(for: path)])
    }

    func copyWikilink() {
        guard let path = openPath else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("[[\(NoteParser.title(for: path))]]", forType: .string)
        status = "Copied [[\(NoteParser.title(for: path))]]"
    }
}

extension VaultStore {
    // MARK: Editor requests

    func completions(kind: String, query: String) -> [CompletionItem] {
        guard let database else { return [] }
        if kind == "tag" {
            return ((try? database.tags(matching: query)) ?? []).map {
                CompletionItem(label: $0.tag, apply: nil, detail: "\($0.count)")
            }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return recentNotes(limit: 15).map { CompletionItem(label: $0.title, apply: nil, detail: Self.folder(of: $0.path)) }
        }
        return ((try? database.titles(matching: trimmed, limit: 20)) ?? []).map {
            CompletionItem(label: $0.title, apply: nil, detail: Self.folder(of: $0.path))
        }
    }

    static func folder(of path: String) -> String {
        path.split(separator: "/").dropLast().joined(separator: "/")
    }

    static let imageTypes: [String: String] = [
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp",
        "svg": "image/svg+xml", "heic": "image/heic",
    ]

    /// `![[target]]`: a note (or one of its sections or blocks) as text, or an image as a data URL.
    /// Only files inside the vault are ever read.
    func embedContent(id: Int, target: String) -> EmbedContent {
        let missing = EmbedContent(id: id, target: target, kind: .missing)
        guard let vault, let database else { return missing }
        let parts = target.split(separator: "#", maxSplits: 1).map(String.init)
        let name = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let anchor = parts.count > 1 ? parts[1] : nil
        guard !name.split(separator: "/").contains("..") else { return missing }

        let ext = (name as NSString).pathExtension.lowercased()
        if let mime = Self.imageTypes[ext] {
            guard let url = findAttachment(named: name, in: vault),
                  let data = try? Data(contentsOf: url), data.count <= 8_000_000 else { return missing }
            return EmbedContent(id: id, target: target, kind: .image, dataURL: "data:\(mime);base64,\(data.base64EncodedString())")
        }
        guard let path = try? database.resolve(linkTarget: name, from: openPath ?? ""),
              let data = try? Data(contentsOf: vault.url(for: path)) else { return missing }
        let note = NoteParser.parse(data: data, path: path, policy: policy)
        var blocks = note.blocks
        var title = note.title
        if let anchor, anchor.hasPrefix("^") {
            blocks = blocks.filter { $0.blockID == String(anchor.dropFirst()) }
            title += " ›"
        } else if let anchor, !anchor.isEmpty {
            let heading = anchor.split(separator: "#").last.map(String.init) ?? anchor
            if let start = blocks.firstIndex(where: { $0.kind == .heading && $0.text == heading }) {
                let level = blocks[start].level ?? 1
                let rest = blocks[(start + 1)...].prefix { $0.kind != .heading || ($0.level ?? 6) > level }
                blocks = Array(rest)
                title += " › \(heading)"
            } else {
                blocks = []
            }
        }
        var text = blocks.map(\.text).joined(separator: "\n\n")
        if text.count > 1_500 { text = String(text.prefix(1_500)) + "…" }
        return EmbedContent(id: id, target: target, kind: .note, title: title, text: text)
    }

    /// Obsidian-style attachment lookup: an exact vault path, next to the open note, `Attachments/`,
    /// then anywhere in the vault by file name (first match, hidden folders skipped).
    private func findAttachment(named name: String, in vault: Vault) -> URL? {
        let manager = FileManager.default
        var candidates = [name, "Attachments/\(name)"]
        if let open = openPath {
            let folder = Self.folder(of: open)
            if !folder.isEmpty { candidates.insert("\(folder)/\(name)", at: 1) }
        }
        for candidate in candidates where manager.fileExists(atPath: vault.url(for: candidate).path(percentEncoded: false)) {
            return vault.url(for: candidate)
        }
        let fileName = (name as NSString).lastPathComponent
        guard let enumerator = manager.enumerator(at: vault.root, includingPropertiesForKeys: nil,
                                                  options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == fileName {
            return url
        }
        return nil
    }
}

/// What the inspector shows for the open note: links in, then facts from its frontmatter.
struct InspectorData {
    struct Row: Identifiable {
        let key: String
        let value: String
        var id: String { key }
    }

    let path: String
    let backlinks: [Backlink]
    let facts: [Row]
    let properties: [Row]
    let tags: [String]
    let outgoing: Int

    init(note: ParsedNote, backlinks: [Backlink]) {
        path = note.path
        self.backlinks = backlinks
        tags = note.tags
        outgoing = note.links.filter { $0.relation == Relation.untyped || Relation(rawValue: $0.relation) != nil }.count
        var facts = [Row(key: "Type", value: note.type.rawValue + (note.kind.map { " · \($0)" } ?? "")),
                     Row(key: "Origin", value: note.origin.rawValue),
                     Row(key: "AI label", value: note.aiLabel.rawValue)]
        if let status = note.status { facts.append(Row(key: "Status", value: status)) }
        if let created = note.created { facts.append(Row(key: "Created", value: created)) }
        self.facts = facts
        let shown = Set(["id", "type", "kind", "origin", "status", "created", "tags", "ai"])
        properties = (note.frontmatter?.properties ?? []).filter { !shown.contains($0.key) }.map { property in
            Row(key: property.key, value: InspectorData.render(property.value))
        }
    }

    static func render(_ value: PropertyValue) -> String {
        switch value {
        case .list(let items): items.map(render).joined(separator: ", ")
        case .map(let map): map.keys.sorted().joined(separator: ", ")
        case .null: "—"
        default: value.text ?? ""
        }
    }
}
