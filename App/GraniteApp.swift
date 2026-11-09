import KBCore
import KBIndex
import SwiftUI

/// Phase 0 shell: open a vault folder, index it, search it. Logic lives in Packages/.
@main
struct GraniteApp: App {
    @State private var store = VaultStore()

    var body: some Scene {
        WindowGroup("granite") {
            SearchView()
                .environment(store)
                .frame(minWidth: 640, minHeight: 420)
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
    private var database: IndexDatabase?
    private var searchTask: Task<Void, Never>?

    func open(_ url: URL) async {
        let vault = Vault(root: url)
        self.vault = vault
        isIndexing = true
        status = "Indexing \(url.lastPathComponent)…"
        defer { isIndexing = false }
        do {
            let policy = try VaultPolicy.load(vaultRoot: vault.root)
            let database = try IndexDatabase(url: vault.supportDirectory.appending(path: "index.sqlite"))
            let report = try await Indexer(database: database, vault: vault, policy: policy).reconcile()
            self.database = database
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
}

struct SearchView: View {
    @Environment(VaultStore.self) private var store
    @State private var query = ""
    @State private var choosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(store.hits, id: \.path) { hit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(hit.title).font(.headline)
                        Text(hit.origin).font(.caption).foregroundStyle(.secondary)
                    }
                    if !hit.headingPath.isEmpty {
                        Text(hit.headingPath).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(hit.snippet).font(.callout).lineLimit(3)
                    Text("\(hit.path):\(hit.startLine)").font(.caption.monospaced()).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
            .overlay {
                if store.hits.isEmpty {
                    ContentUnavailableView(store.vault == nil ? "No vault open" : "No results",
                                           systemImage: "magnifyingglass",
                                           description: Text(store.status))
                }
            }
            Divider()
            Text(store.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .searchable(text: $query, prompt: "Search notes")
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
