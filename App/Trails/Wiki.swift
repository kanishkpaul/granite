import Foundation
import KBAI
import KBCore
import KBIndex
import SwiftUI

/// The scoped LLM wiki in the app: define a reference domain, build or rebuild its pages.
extension VaultStore {
    var wikiDomains: [WikiDomain] { vault.map(WikiRegistry.load) ?? [] }

    func buildWiki(_ domain: WikiDomain) async {
        guard let vault, let writer, let indexer, let models, let database else { return }
        var domains = wikiDomains.filter { $0.name != domain.name }
        domains.append(domain)
        try? await WikiRegistry.save(domains, vault: vault, writer: writer)
        let reranker = semantic.isEnabled ? await semantic.loadReranker() : nil
        let searcher = semantic.searcher ?? HybridSearcher(database: database, vectors: nil, embedder: nil, reranker: reranker)
        status = "Building the \(domain.name) wiki…"
        do {
            let report = try await WikiBuilder(models: models, indexer: indexer, writer: writer, searcher: searcher).build(domain)
            if report.sources == 0 {
                status = "No sources in \(domain.folders.joined(separator: ", ")) for \(domain.name)."
                return
            }
            status = "\(domain.name) wiki: \(report.pages.count - 1) page(s) from \(report.sources) source(s)"
                + (report.localModel ? " (local model: check the citations)" : "")
            refreshLists()
            if let index = report.pages.first { openNote(index) }
        } catch {
            status = "Wiki failed: \(error)"
        }
    }
}

/// ⌘K "Build a wiki for a domain…".
struct WikiSheet: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var folders = "Papers, Clippings, References"
    @State private var tags = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wiki for a reference domain").font(.headline)
            Text("Pages under AI/Wiki/ compiled from your sources only (papers, clippings, references), never your own notes. Every sentence cites a verified passage.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Domain, e.g. Information retrieval", text: $name).textFieldStyle(.roundedBorder)
            TextField("Source folders", text: $folders).textFieldStyle(.roundedBorder)
            TextField("Only sources tagged (optional, comma-separated)", text: $tags).textFieldStyle(.roundedBorder)
            if !store.wikiDomains.isEmpty {
                Text("Existing: " + store.wikiDomains.map(\.name).joined(separator: ", ") + ". Same name rebuilds it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Build") {
                    let split = { (text: String) in text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                    let domain = WikiDomain(name: name.trimmingCharacters(in: .whitespaces), folders: split(folders), tags: split(tags))
                    Task { await store.buildWiki(domain) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || folders.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
