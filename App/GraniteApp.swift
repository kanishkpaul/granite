import KBCore
import KBIndex
import SwiftUI

/// Phase 0 shell: open a vault, search it, edit notes in the CodeMirror editor.
/// `--editor-bench <file> [--bench-out <json>]` runs the spike A benchmark and quits.
@main
struct GraniteApp: App {
    @State private var store = VaultStore()
    private let bench = BenchArguments(ProcessInfo.processInfo.arguments)

    var body: some Scene {
        WindowGroup("granite") {
            if let bench {
                EditorBenchView(arguments: bench)
            } else {
                MainView()
                    .environment(store)
                    .frame(minWidth: 820, minHeight: 520)
            }
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
    private var loadedVersion = 0

    init() {
        editor.addListener { [weak self] message in self?.handle(message) }
    }

    func open(_ url: URL) async {
        let vault = Vault(root: url)
        self.vault = vault
        isIndexing = true
        status = "Indexing \(url.lastPathComponent)…"
        defer { isIndexing = false }
        do {
            let policy = try VaultPolicy.load(vaultRoot: vault.root)
            let database = try IndexDatabase(url: vault.supportDirectory.appending(path: "index.sqlite"))
            let indexer = Indexer(database: database, vault: vault, policy: policy)
            let report = try await indexer.reconcile()
            self.database = database
            self.indexer = indexer
            self.writer = SafeWriter(vault: vault)
            status = report.description
        } catch {
            status = "Indexing failed: \(error)"
        }
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

    func openNote(_ path: String, line: Int? = nil) {
        guard let vault else { return }
        do {
            let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
            loadedVersion += 1
            openPath = path
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
            Task { await save(text, to: path) }
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
            _ = try await indexer.update(paths: [path])
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
