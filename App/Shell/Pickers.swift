import KBCore
import KBIndex
import SwiftUI

/// A keyboard-first picker: type to filter, ↑↓ to move, ↩ to choose, Esc to close.
struct PickerList<Item: Identifiable, Row: View>: View {
    let placeholder: String
    @Binding var query: String
    let items: [Item]
    let row: (Item, Bool) -> Row
    let choose: (Item) -> Void
    @State private var highlighted = 0
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(placeholder: String, query: Binding<String>, items: [Item],
         @ViewBuilder row: @escaping (Item, Bool) -> Row, choose: @escaping (Item) -> Void) {
        self.placeholder = placeholder
        self._query = query
        self.items = items
        self.row = row
        self.choose = choose
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .padding(14)
                .focused($focused)
                .onSubmit { pick() }
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
            Divider()
            ScrollViewReader { proxy in
                List(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item, index == highlighted)
                        .contentShape(Rectangle())
                        .onTapGesture { choose(item); dismiss() }
                        .listRowBackground(index == highlighted ? Color.accentColor.opacity(0.2) : Color.clear)
                        .id(index)
                }
                .listStyle(.plain)
                .onChange(of: highlighted) { _, index in proxy.scrollTo(index) }
            }
        }
        .frame(width: 560, height: 380)
        .onAppear { focused = true }
        .onChange(of: query) { highlighted = 0 }
        .onExitCommand { dismiss() }
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !items.isEmpty else { return .handled }
        highlighted = min(max(0, highlighted + delta), items.count - 1)
        return .handled
    }

    private func pick() {
        guard items.indices.contains(highlighted) else { return }
        choose(items[highlighted])
        dismiss()
    }
}

/// ⌘O: open a note by title or alias; the last row creates a new note with the typed title.
struct QuickSwitcher: View {
    @Environment(VaultStore.self) private var store
    @Bindable var shell: ShellState
    @State private var query = ""

    enum Choice: Identifiable {
        case note(path: String, title: String, type: String)
        case create(String)

        var id: String {
            switch self {
            case .note(let path, _, _): path
            case .create(let title): "create:" + title
            }
        }
    }

    var choices: [Choice] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if shell.switcherCreates { return [.create(trimmed.isEmpty ? "Untitled" : trimmed)] }
        let notes: [Choice] = trimmed.isEmpty
            ? store.recentNotes().map { .note(path: $0.path, title: $0.title, type: $0.type) }
            : store.titles(matching: trimmed).map { .note(path: $0.path, title: $0.title, type: $0.type) }
        let exact = notes.contains { if case .note(_, let title, _) = $0 { title.lowercased() == trimmed.lowercased() } else { false } }
        return trimmed.isEmpty || exact ? notes : notes + [.create(trimmed)]
    }

    var body: some View {
        PickerList(placeholder: shell.switcherCreates ? "New note title" : "Open a note…", query: $query, items: choices) { choice, _ in
            switch choice {
            case .note(let path, let title, let type):
                HStack {
                    Text(title)
                    Spacer()
                    Text(type == "note" ? path : "\(type) · \(path)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            case .create(let title):
                Label("Create “\(title)”", systemImage: "plus")
            }
        } choose: { choice in
            switch choice {
            case .note(let path, _, _): store.openNote(path)
            case .create(let title): Task { await store.newNote(title: title) }
            }
        }
        .onDisappear { shell.switcherCreates = false }
    }
}

/// ⌘K: every command, then matching notes.
struct CommandPalette: View {
    @Environment(VaultStore.self) private var store
    @Bindable var shell: ShellState
    let chooseVault: () -> Void
    @State private var query = ""

    struct Entry: Identifiable {
        let id: String
        let title: String
        let detail: String
        let action: @MainActor () -> Void
    }

    var commands: [Entry] {
        let git = AppModel.shared.git
        return [
            Entry(id: "new", title: "New note", detail: "⌘N") { shell.switcherCreates = true; shell.showSwitcher = true },
            Entry(id: "today", title: "Open today's daily note", detail: "⌘D") { Task { await store.openToday() } },
            Entry(id: "ask", title: "Ask your notes…", detail: "⌘J") { shell.showAsk = true },
            Entry(id: "switch", title: "Open note…", detail: "⌘O") { shell.showSwitcher = true },
            Entry(id: "capture", title: "Capture…", detail: "⌃⌥Space") { AppModel.shared.capture.show(trigger: .menu) },
            Entry(id: "search", title: "Search notes", detail: "⌘F") { shell.focusSearch += 1 },
            Entry(id: "inspector", title: "Toggle inspector", detail: "⌥⌘I") { shell.showInspector.toggle() },
            Entry(id: "wikilink", title: "Copy link to this note", detail: "[[…]]") { store.copyWikilink() },
            Entry(id: "rename", title: "Rename note…", detail: "updates links") { shell.showRename = true },
            Entry(id: "move", title: "Move note to folder…", detail: "") { shell.showMove = true },
            Entry(id: "inbox", title: "Go to Inbox", detail: "\(store.inboxCount)") { store.selection = .inbox },
            Entry(id: "proposals", title: "Go to Proposals", detail: "\(store.openProposals.count)") { store.selection = .proposals },
            Entry(id: "importPDF", title: "Import PDF…", detail: "Papers/") { shell.showImportPDF = true },
            Entry(id: "enrich", title: "Look up this paper (Crossref, OpenAlex, Semantic Scholar)", detail: "DOI or title only") {
                Task { await store.enrichOpenPaper() }
            },
            Entry(id: "promote", title: "Promote selection to claim…", detail: "⌥⌘P") { shell.promoteSelection(store) },
            Entry(id: "claims", title: "Go to Claims", detail: "\(store.claims.count)") { store.selection = .claims },
            Entry(id: "metrics", title: "Metrics dashboard", detail: "§11") { shell.showMetrics = true },
            Entry(id: "trails", title: "Suggest trails from your links", detail: "proposals") { Task { await store.suggestTrails() } },
            Entry(id: "graph", title: "Expand this paper's literature graph", detail: "OpenAlex") { Task { await store.expandLiteratureGraph() } },
            Entry(id: "scanRepos", title: "Scan code repositories", detail: "\(store.repos.count) repo(s)") { Task { await store.scanRepos() } },
            Entry(id: "weekly", title: "Weekly review…", detail: store.weeklyReviewDue ? "due" : "") { shell.showWeekly = true },
            Entry(id: "digest", title: "Run digest now", detail: "AI/Digests") { Task { await store.runDigest() } },
            Entry(id: "latestDigest", title: "Open latest digest", detail: store.latestDigest().map { NoteParser.title(for: $0) } ?? "none yet") {
                if let path = store.latestDigest() { store.openNote(path) }
            },
            Entry(id: "review", title: "Review prompts", detail: "\(store.dueCount) due · ⌃⌘R") { shell.showReview = true },
            Entry(id: "makePrompts", title: "Make prompts from this note", detail: "proposals") { Task { await store.makePrompts() } },
            Entry(id: "suggest", title: "Suggest links for this week's notes", detail: "proposals") {
                Task { await store.suggestLinks() }
            },
            Entry(id: "reveal", title: "Reveal note in Finder", detail: "") { store.revealInFinder() },
            Entry(id: "commit", title: "Commit vault to git now", detail: git.isRepository ? "" : "not a git repository") {
                Task { await git.commit() }
            },
            Entry(id: "vault", title: "Open another vault…", detail: "") { chooseVault() },
        ]
    }

    var entries: [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return commands }
        let words = trimmed.split(separator: " ")
        let matched = commands.filter { entry in words.allSatisfy { entry.title.lowercased().contains($0) } }
        let notes = store.titles(matching: trimmed, limit: 15).map { note in
            Entry(id: "note:" + note.path, title: note.title, detail: note.path) { store.openNote(note.path) }
        }
        return matched + notes
    }

    var body: some View {
        PickerList(placeholder: "Type a command or a note title…", query: $query, items: entries) { entry, _ in
            HStack {
                Text(entry.title)
                Spacer()
                Text(entry.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } choose: { entry in
            // Let the sheet close before a command opens another one.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                entry.action()
            }
        }
    }
}
