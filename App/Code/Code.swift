import Foundation
import KBCode
import KBCore
import KBIndex
import SwiftUI

/// Code-decision records in the app: repositories to follow, scans, decision-stub proposals.
extension VaultStore {
    var repos: [RepoConfig] { vault.map(RepoRegistry.load) ?? [] }

    func addRepo(_ url: URL) async {
        guard let vault, let writer else { return }
        var list = repos
        let name = url.lastPathComponent
        guard !list.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        var path = url.path(percentEncoded: false)
        if path.hasPrefix(home) { path = "~/" + path.dropFirst(home.count).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        list.append(RepoConfig(name: list.contains { $0.name == name } ? "\(name)-\(list.count + 1)" : name, path: path))
        try? await RepoRegistry.save(list, vault: vault, writer: writer)
        await scanRepos()
    }

    func removeRepo(_ repo: RepoConfig) async {
        guard let vault, let writer else { return }
        try? await RepoRegistry.save(repos.filter { $0 != repo }, vault: vault, writer: writer)
    }

    /// Scans every repository: hub notes, ADR and agent-memory imports, trailer links, decision stubs.
    func scanRepos() async {
        guard let vault, let writer, let database, !repos.isEmpty else { return }
        let scanner = CodeScanner(vault: vault, writer: writer) { reference in
            if let record = try? database.note(id: reference) { return record.path }
            if let path = try? database.resolve(linkTarget: reference, from: ""),
               let record = try? database.note(path: path), record.type == "decision" { return path }
            return nil
        }
        var touched: [String] = []
        var proposed = 0
        var problems: [String] = []
        for repo in repos {
            do {
                let report = try await scanner.scan(repo)
                touched += [report.hub] + report.sources + report.linked
                for candidate in report.candidates {
                    if (try? await proposalStore?.create(CodeScanner.stub(for: candidate, date: ClaimDay.string(Date())))) != nil {
                        proposed += 1
                    }
                }
                problems += report.unknownTrailers.map { "\(repo.name) \($0)" }
            } catch {
                problems.append("\(repo.name): \(error)")
            }
        }
        _ = try? await indexer?.update(paths: touched)
        refreshLists()
        await refreshProposals()
        status = "Scanned \(repos.count) repo(s): \(Set(touched).count) note(s) updated, \(proposed) decision stub(s) proposed"
            + (problems.isEmpty ? "" : " · unknown trailers: " + problems.prefix(3).joined(separator: ", "))
    }
}

/// Settings → Code: repositories granite follows.
struct CodeSettingsSection: View {
    @Environment(VaultStore.self) private var store
    @State private var choosing = false
    @State private var repos: [RepoConfig] = []

    var body: some View {
        Section("Code repositories") {
            ForEach(repos) { repo in
                HStack {
                    VStack(alignment: .leading) {
                        Text(repo.name)
                        Text(repo.path).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove") { Task { await store.removeRepo(repo); repos = store.repos } }
                }
            }
            HStack {
                Button("Add Repository…") { choosing = true }
                Button("Scan Now") { Task { await store.scanRepos() } }.disabled(repos.isEmpty)
            }
            Text("Imports ADRs and CLAUDE.md/AGENTS.md as sources, links commits with a `Granite-Decision:` trailer, and proposes decision records for commits that change direction.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await store.addRepo(url); repos = store.repos }
        }
        .task { repos = store.repos }
    }
}
