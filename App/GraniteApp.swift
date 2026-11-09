import CryptoKit
import KBCapture
import KBCore
import KBIndex
import SwiftUI

/// granite: search, edit and capture into a Markdown vault. Keeps running in the menu bar
/// when its window closes, so the capture hotkey always works.
/// `--editor-bench <file> [--bench-out <json>]` runs the spike A benchmark and quits.
@main
struct GraniteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let bench = BenchArguments(ProcessInfo.processInfo.arguments)

    var body: some Scene {
        WindowGroup("granite", id: "main") {
            if let bench {
                EditorBenchView(arguments: bench)
            } else {
                MainView()
                    .environment(AppModel.shared.store)
                    .frame(minWidth: 820, minHeight: 520)
            }
        }
        MenuBarExtra("granite", systemImage: "square.and.pencil", isInserted: .constant(bench == nil)) {
            MenuBarContent()
        }
        Settings {
            SettingsView().environment(AppModel.shared.store)
        }
    }
}

/// Receives `granite://` URLs (AppKit delivers them to the delegate, not to a scene,
/// so no new window opens for a capture from a bookmarklet or another app).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            for url in urls { AppModel.shared.handle(url) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard BenchArguments(ProcessInfo.processInfo.arguments) == nil else { return }
            AppModel.shared.start()
        }
    }
}

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
        isIndexing = true
        status = "Indexing \(url.lastPathComponent)…"
        syncTask?.cancel()
        do {
            let policy = try VaultPolicy.load(vaultRoot: vault.root)
            let database = try IndexDatabase(url: vault.supportDirectory.appending(path: "index.sqlite"))
            let indexer = Indexer(database: database, vault: vault, policy: policy)
            self.database = database
            self.indexer = indexer
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
        loadedVersion += 1
        editorHash = hash
        let text = String(decoding: data, as: UTF8.self)
        editor.send(.load(path: path, text: text, version: loadedVersion, cursor: min(cursor, text.utf16.count)))
        sendResolved(for: path)
        status = "Reloaded \(path): changed on disk"
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
}

struct MainView: View {
    @Environment(VaultStore.self) private var store
    @State private var query = ""
    @State private var choosingFolder = false

    var body: some View {
        NavigationSplitView {
            List(store.hits, id: \.path) { hit in
                Button {
                    store.openNote(hit.path, line: hit.startLine)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hit.title).font(.headline)
                        if !hit.headingPath.isEmpty {
                            Text(hit.headingPath).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(hit.snippet).font(.callout).lineLimit(3).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if store.hits.isEmpty {
                    ContentUnavailableView(store.vault == nil ? "No vault open" : "Search your notes",
                                           systemImage: "magnifyingglass", description: Text(store.status))
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            EditorView(controller: store.editor)
                .overlay(alignment: .bottomLeading) {
                    Text(store.openPath ?? store.status)
                        .font(.caption).foregroundStyle(.secondary).padding(8)
                }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search notes")
        .onChange(of: query) { _, text in store.search(text) }
        .toolbar {
            Button("Open Vault…", systemImage: "folder") { choosingFolder = true }
                .disabled(store.isIndexing)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await store.open(url) }
        }
    }
}
