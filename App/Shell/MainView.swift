import KBCore
import KBIndex
import SwiftUI

struct MainView: View {
    @Environment(VaultStore.self) private var store
    @Bindable var shell: ShellState
    @State private var choosingFolder = false
    @State private var renameTitle = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } content: {
            NoteListView(query: shell.query)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                .searchable(text: $shell.query, placement: .toolbar, prompt: "Search notes")
                .searchFocused($searchFocused)
        } detail: {
            EditorView(controller: store.editor)
                .overlay(alignment: .bottomLeading) {
                    Text(store.status).font(.caption).foregroundStyle(.secondary).padding(8).lineLimit(1)
                }
                .overlay {
                    if store.openPath == nil {
                        ContentUnavailableView(store.vault == nil ? "No vault open" : "No note open",
                                               systemImage: "doc.text",
                                               description: Text(store.vault == nil
                                                   ? "Open a vault folder to start."
                                                   : "⌘O to open a note · ⌘N for a new one · ⌘D for today"))
                    }
                }
                .inspector(isPresented: $shell.showInspector) {
                    InspectorView()
                        .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
                }
        }
        .navigationTitle(store.openPath.map { NoteParser.title(for: $0) } ?? "granite")
        .onChange(of: shell.query) { _, text in store.search(text) }
        .onChange(of: shell.focusSearch) { searchFocused = true }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Open Vault…", systemImage: "folder") { choosingFolder = true }
                    .disabled(store.isIndexing)
            }
            ToolbarItem {
                Button("Inspector", systemImage: "sidebar.right") { shell.showInspector.toggle() }
            }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await store.open(url) }
        }
        .sheet(isPresented: $shell.showSwitcher) {
            QuickSwitcher(shell: shell).environment(store)
        }
        .sheet(isPresented: $shell.showPalette) {
            CommandPalette(shell: shell, chooseVault: { choosingFolder = true }).environment(store)
        }
        .sheet(isPresented: $shell.showMove) {
            MovePicker().environment(store)
        }
        .alert("Rename note", isPresented: $shell.showRename) {
            TextField("Title", text: $renameTitle)
            Button("Rename") { Task { await store.renameOpenNote(to: renameTitle) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Links to this note are updated everywhere.")
        }
        .onChange(of: shell.showRename) { _, showing in
            if showing, let path = store.openPath { renameTitle = NoteParser.title(for: path) }
        }
    }
}

struct SidebarView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section {
                Label {
                    HStack {
                        Text("Inbox")
                        Spacer()
                        if store.inboxCount > 0 { Text("\(store.inboxCount)").foregroundStyle(.secondary).monospacedDigit() }
                    }
                } icon: { Image(systemName: "tray") }
                .tag(VaultStore.SidebarItem.inbox)
                Label("All notes", systemImage: "doc.on.doc").tag(VaultStore.SidebarItem.all)
                Button {
                    Task { await store.openToday() }
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                .buttonStyle(.plain)
            }
            Section("Folders") {
                ForEach(store.folders.filter { $0.path != "Inbox" }) { folder in
                    HStack {
                        Text(folder.name)
                        Spacer()
                        Text("\(folder.noteCount)").foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.leading, CGFloat(folder.depth) * 12)
                    .tag(VaultStore.SidebarItem.folder(folder.path))
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct NoteListView: View {
    @Environment(VaultStore.self) private var store
    let query: String

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty && store.selection == .inbox {
                InboxView()
            } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                List(store.listed, id: \.path) { note in
                    row(title: note.title, detail: folder(of: note.path), trailing: note.modified.formatted(.relative(presentation: .named)),
                        path: note.path)
                }
                .overlay {
                    if store.listed.isEmpty && store.vault != nil {
                        ContentUnavailableView("Nothing here yet", systemImage: "tray")
                    }
                }
            } else {
                List(store.hits, id: \.path) { hit in
                    row(title: hit.title, detail: hit.snippet, trailing: hit.headingPath, path: hit.path, line: hit.startLine)
                }
                .overlay {
                    if store.hits.isEmpty { ContentUnavailableView.search(text: query) }
                }
            }
        }
    }

    private func folder(of path: String) -> String {
        path.split(separator: "/").dropLast().joined(separator: "/")
    }

    private func row(title: String, detail: String, trailing: String, path: String, line: Int? = nil) -> some View {
        Button {
            store.openNote(path, line: line)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline).lineLimit(1)
                    Spacer()
                    Text(trailing).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                if !detail.isEmpty {
                    Text(detail).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(store.openPath == path ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}

struct InspectorView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        if let data = store.inspector {
            List {
                Section("Backlinks (\(data.backlinks.count))") {
                    if data.backlinks.isEmpty {
                        Text("No notes link here yet.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(data.backlinks.enumerated()), id: \.offset) { _, link in
                        Button {
                            store.openNote(link.path, line: link.line)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(link.title)
                                Text(link.relation == "links" ? "line \(link.line)" : "\(link.relation) · line \(link.line)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Note") {
                    ForEach(data.facts) { row in LabeledContent(row.key, value: row.value) }
                    LabeledContent("Outgoing links", value: "\(data.outgoing)")
                    if !data.tags.isEmpty { LabeledContent("Tags", value: data.tags.map { "#\($0)" }.joined(separator: " ")) }
                }
                if !data.properties.isEmpty {
                    Section("Properties") {
                        ForEach(data.properties) { row in LabeledContent(row.key, value: row.value) }
                    }
                }
            }
        } else {
            ContentUnavailableView("No note open", systemImage: "info.circle")
        }
    }
}
