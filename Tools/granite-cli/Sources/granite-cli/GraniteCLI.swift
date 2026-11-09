import ArgumentParser
import Foundation
import KBAI
import KBGit
import KBCore
import KBIndex
import KBTestSupport

@main
struct GraniteCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "granite-cli",
        abstract: "Index, search and inspect a granite vault from the terminal.",
        subcommands: [Fixture.self, Index.self, Search.self, Titles.self, Backlinks.self, Stats.self, Eval.self,
                      Parse.self, Models.self, Watch.self, Git.self]
    )
}

/// Options shared by commands that open a vault's index.
struct VaultOptions: ParsableArguments {
    @Option(name: .long, help: "Vault folder.")
    var vault: String

    @Option(name: .long, help: "index.sqlite path (default: ~/Library/Application Support/granite/<vault-id>/index.sqlite).")
    var db: String?

    var vaultValue: Vault { Vault(root: URL(filePath: (vault as NSString).expandingTildeInPath)) }

    var databaseURL: URL {
        if let db { return URL(filePath: (db as NSString).expandingTildeInPath) }
        return vaultValue.supportDirectory.appending(path: "index.sqlite")
    }

    func open() throws -> IndexDatabase { try IndexDatabase(url: databaseURL) }

    func policy() throws -> VaultPolicy { try VaultPolicy.load(vaultRoot: vaultValue.root) }
}

struct Fixture: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate a synthetic vault (refuses non-empty folders).")

    @Option(help: "Number of notes.") var notes = 1_000
    @Option(help: "Output folder.") var out: String
    @Option(help: "RNG seed.") var seed: UInt64 = 42
    @Option(help: "Synthetic eval queries to write to .granite/eval/synthetic.jsonl.") var queries = 200

    func run() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        let url = URL(filePath: (out as NSString).expandingTildeInPath)
        let summary = try FixtureGenerator(noteCount: notes, seed: seed, queryCount: queries).write(to: url)
        let elapsed = clock.now - start
        print("wrote \(summary.notes) notes (\(summary.bytes / 1_048_576) MiB) and \(summary.queries.count) queries to \(url.path(percentEncoded: false)) in \(elapsed.formatted(.units(allowed: [.seconds, .milliseconds])))")
    }
}

struct Index: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Reconcile the index with the vault (cold or incremental).")

    @OptionGroup var options: VaultOptions
    @Flag(help: "Delete the index first and rebuild from scratch.") var rebuild = false

    func run() async throws {
        if rebuild {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: options.databaseURL.path(percentEncoded: false) + suffix)
            }
        }
        let database = try options.open()
        let indexer = Indexer(database: database, vault: options.vaultValue, policy: try options.policy())
        let report = try await indexer.reconcile()
        print(report)
        print("index: \(options.databaseURL.path(percentEncoded: false))")
    }
}

struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Full-text search (BM25), best block per note.")

    @OptionGroup var options: VaultOptions
    @Argument(help: "Query words.") var query: [String]
    @Option(help: "Maximum results.") var limit = 10
    @Flag(help: "Include the AI/ layer (excluded from evidence by default).") var includeAI = false
    @Option(help: "Strictest allowed label: cloud, pcc, local or none.") var maxLabel: String?
    @Option(help: "Restrict to a folder prefix (repeatable).") var folder: [String] = []
    @Flag(help: "Pass the query to FTS5 unchanged.") var raw = false
    @Flag(help: "Print JSON lines.") var json = false

    func run() async throws {
        let database = try options.open()
        let label = try maxLabel.map { value in
            guard let label = AILabel(rawValue: value) else { throw ValidationError("unknown label \(value)") }
            return label
        }
        let hits = try database.search(query.joined(separator: " "), options: SearchOptions(
            limit: limit, includeAI: includeAI, maxLabel: label, folders: folder, raw: raw))
        if json {
            for hit in hits {
                let object: [String: Any] = ["path": hit.path, "title": hit.title, "type": hit.type, "origin": hit.origin,
                                             "heading": hit.headingPath, "line": hit.startLine,
                                             "block": hit.blockID ?? NSNull(), "snippet": hit.snippet, "score": hit.score]
                let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
                print(String(decoding: data, as: UTF8.self))
            }
            return
        }
        if hits.isEmpty { print("no matches"); return }
        for hit in hits {
            let anchor = hit.blockID.map { "#^\($0)" } ?? ""
            print("\(hit.path):\(hit.startLine)\(anchor)  [\(hit.origin)]")
            if !hit.headingPath.isEmpty { print("  § \(hit.headingPath)") }
            print("  \(hit.snippet.replacingOccurrences(of: "\n", with: " "))")
        }
    }
}

struct Titles: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Quick-switcher title and alias match.")
    @OptionGroup var options: VaultOptions
    @Argument var text: String
    @Option var limit = 20

    func run() async throws {
        for note in try options.open().titles(matching: text, limit: limit) {
            print("\(note.title)\t\(note.type)\t\(note.path)")
        }
    }
}

struct Backlinks: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Notes that link to a note (vault-relative path).")
    @OptionGroup var options: VaultOptions
    @Argument var path: String

    func run() async throws {
        let links = try options.open().backlinks(to: path)
        if links.isEmpty { print("no backlinks") }
        for link in links { print("\(link.path):\(link.line)\t\(link.relation)") }
    }
}

struct Stats: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Index counts and the most-used unresolved links.")
    @OptionGroup var options: VaultOptions

    func run() async throws {
        let database = try options.open()
        let stats = try database.stats()
        print("objects \(stats.objects)  blocks \(stats.blocks)  links \(stats.links)  unresolved \(stats.unresolvedLinks)  tags \(stats.tags)  yaml errors \(stats.yamlErrors)")
        let unresolved = try database.unresolvedLinks(limit: 10)
        if !unresolved.isEmpty {
            print("top unresolved:")
            for item in unresolved { print("  \(item.count)\t\(item.target)") }
        }
    }
}

struct Eval: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Re-find eval: Recall@5/10, MRR and query latency over a JSONL query set.")

    @OptionGroup var options: VaultOptions
    @Option(help: "JSONL of {query, expected} (default: <vault>/.granite/eval/synthetic.jsonl).") var queries: String?
    @Option(help: "Repeat the query set this many times for steadier latency numbers.") var repeats = 3

    func run() async throws {
        let database = try options.open()
        let path = queries.map { ($0 as NSString).expandingTildeInPath }
            ?? options.vaultValue.root.appending(path: ".granite/eval/synthetic.jsonl").path(percentEncoded: false)
        let decoder = JSONDecoder()
        let set = try String(contentsOfFile: path, encoding: .utf8)
            .split(separator: "\n").filter { !$0.isEmpty }
            .map { try decoder.decode(FixtureQuery.self, from: Data($0.utf8)) }
        guard !set.isEmpty else { throw ValidationError("no queries in \(path)") }

        var at5 = 0, at10 = 0
        var reciprocal = 0.0
        var latencies: [Double] = []
        let clock = ContinuousClock()
        for round in 0..<max(1, repeats) {
            for item in set {
                let start = clock.now
                let hits = try database.search(item.query, options: SearchOptions(limit: 10, includeAI: true))
                let elapsed = clock.now - start
                latencies.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
                guard round == 0 else { continue }
                if let rank = hits.firstIndex(where: { $0.path == item.expected }) {
                    if rank < 5 { at5 += 1 }
                    at10 += 1
                    reciprocal += 1.0 / Double(rank + 1)
                }
            }
        }
        latencies.sort()
        func percentile(_ p: Double) -> Double { latencies[min(latencies.count - 1, Int(Double(latencies.count) * p))] }
        let n = Double(set.count)
        print(String(format: "queries %d  recall@5 %.3f  recall@10 %.3f  MRR %.3f", set.count, Double(at5) / n,
                     Double(at10) / n, reciprocal / n))
        print(String(format: "latency ms over %d runs: p50 %.2f  p95 %.2f  max %.2f", latencies.count, percentile(0.5),
                     percentile(0.95), latencies.last ?? 0))
    }
}

struct Parse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show how granite parses one Markdown file.")
    @Argument(help: "Markdown file.") var file: String
    @Option(help: "Vault-relative path to apply folder policy (default: Notes/<name>).") var path: String?

    func run() async throws {
        let url = URL(filePath: (file as NSString).expandingTildeInPath)
        let data = try Data(contentsOf: url)
        let note = NoteParser.parse(data: data, path: path ?? "Notes/\(url.lastPathComponent)", policy: .builtIn)
        print("title \(note.title)  type \(note.type.rawValue)  origin \(note.origin.rawValue)  ai \(note.aiLabel.rawValue)  id \(note.id ?? "-")")
        if let error = note.frontmatter?.error { print("yaml error: \(error)") }
        for property in note.frontmatter?.properties ?? [] { print("  \(property.key): \(property.value)") }
        print("tags: \(note.tags.joined(separator: ", "))")
        for link in note.links {
            let anchor = link.heading.map { "#\($0)" } ?? link.blockID.map { "#^\($0)" } ?? ""
            print("link L\(link.line) \(link.relation)\(link.isEmbed ? " (embed)" : "") → \(link.target)\(anchor)")
        }
        for block in note.blocks {
            let id = block.blockID.map { " ^\($0)" } ?? ""
            print("block L\(block.startLine)-\(block.endLine) \(block.kind.rawValue)\(id)  \(block.headingPath.isEmpty ? "" : "§ \(block.headingPath)  ")\(block.text.prefix(60).replacingOccurrences(of: "\n", with: " ⏎ "))")
        }
    }
}

struct Models: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Which model routes work on this Mac (on-device, PCC, MLX, Claude).")

    @Flag(help: "Send a fixed one-line prompt to each available route and time it.") var send = false

    func run() async throws {
        for status in await ModelProbe.run(sendPrompt: send) {
            var line = "\(status.route.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(status.available ? "yes" : "no ")  \(status.detail)"
            if let context = status.contextSize { line += "  context \(context)" }
            if let ms = status.latencyMs { line += String(format: "  %.0f ms", ms) }
            if let reply = status.reply { line += "  reply: \(reply.prefix(40))" }
            print(line)
        }
    }
}

struct Watch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Keep the index current as files change (FSEvents); prints each update. Ctrl-C to stop.")

    @OptionGroup var options: VaultOptions

    func run() async throws {
        setvbuf(stdout, nil, _IOLBF, 0)  // line-buffered, so `watch | tee` and log files update live
        let database = try options.open()
        let indexer = Indexer(database: database, vault: options.vaultValue, policy: try options.policy())
        print("watching \(options.vaultValue.root.path(percentEncoded: false))")
        try await VaultSync(indexer: indexer).run { update in
            let stamp = Date().formatted(.iso8601.time(includingFractionalSeconds: true))
            switch update.kind {
            case .fullReconcile:
                print("\(stamp) full reconcile: \(update.report)")
            case .incremental:
                let shown = update.paths.prefix(5).joined(separator: ", ") + (update.paths.count > 5 ? ", …" : "")
                print("\(stamp) \(update.report)  [\(shown)]")
            }
        }
    }
}

struct Git: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "The vault's git safety net: status, commit (with the deletion alarm), push, init.")

    @Option(help: "Vault folder.") var vault: String
    @Argument(help: "status, commit, push or init.") var action = "status"
    @Flag(help: "With commit: commit even if the deletion alarm fires.") var allowAlarm = false

    func run() async throws {
        let service = GitService(root: URL(filePath: (vault as NSString).expandingTildeInPath))
        switch action {
        case "status":
            let state = try await service.state()
            guard state.isRepository else { print("not a git repository (granite-cli git init)"); return }
            print("branch \(state.branch ?? "?")  remotes \(state.remotes.joined(separator: ", "))  pending \(state.pending.count)")
            if let busy = state.busy { print("busy: \(busy)") }
            for change in state.pending.prefix(20) { print("  \(change.kind.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(change.path)") }
        case "commit":
            print(Self.describe(try await service.autoCommit(allowAlarm: allowAlarm)))
        case "push":
            print(try await service.push())
        case "init":
            print(Self.describe(try await service.initialize()))
        default:
            throw ValidationError("unknown action \(action): use status, commit, push or init")
        }
    }

    static func describe(_ outcome: CommitOutcome) -> String {
        switch outcome {
        case .committed(let sha, let summary): "committed \(sha): \(summary)"
        case .nothingToCommit: "nothing to commit"
        case .paused(let alarm): "PAUSED: \(alarm.reason). Review, then rerun with --allow-alarm if intended."
        case .skipped(let reason): "skipped: \(reason)"
        case .notARepository: "not a git repository"
        }
    }
}
