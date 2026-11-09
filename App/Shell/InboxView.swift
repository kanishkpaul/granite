import KBCapture
import SwiftUI

/// The Inbox as a decide queue: items older than 14 days first, each with make-note,
/// append-to-note and archive; bankruptcy for everything older than 60 days.
struct InboxView: View {
    @Environment(VaultStore.self) private var store
    @State private var makingNote: InboxItem?
    @State private var noteTitle = ""
    @State private var appending: InboxItem?
    @State private var confirmBankruptcy = false

    private var due: [InboxItem] { store.inboxItems.filter { $0.ageDays > InboxQueue.decideAfterDays } }
    private var fresh: [InboxItem] { store.inboxItems.filter { $0.ageDays <= InboxQueue.decideAfterDays } }
    private var bankrupt: Int { store.inboxItems.filter { $0.ageDays > InboxQueue.bankruptAfterDays }.count }

    var body: some View {
        List {
            if !due.isEmpty {
                Section {
                    ForEach(due) { item in row(item, decide: true) }
                } header: {
                    HStack {
                        Text("Decide · \(due.count)").help("Older than \(InboxQueue.decideAfterDays) days")
                        Spacer()
                        if bankrupt > 0 {
                            Button("Bankruptcy…") { confirmBankruptcy = true }
                                .buttonStyle(.link)
                        }
                    }
                }
            }
            Section("Recent") {
                ForEach(fresh) { item in row(item, decide: false) }
            }
        }
        .overlay {
            if store.inboxItems.isEmpty { ContentUnavailableView("Inbox zero", systemImage: "tray") }
        }
        .alert("Make a note", isPresented: Binding(get: { makingNote != nil }, set: { if !$0 { makingNote = nil } })) {
            TextField("Title", text: $noteTitle)
            Button("Make Note") {
                if let item = makingNote { Task { await store.inboxMakeNote(item, title: noteTitle) } }
                makingNote = nil
            }
            Button("Cancel", role: .cancel) { makingNote = nil }
        } message: {
            Text("Moves the capture to Notes/ under this title.")
        }
        .sheet(item: $appending) { item in
            AppendPicker(item: item).environment(store)
        }
        .confirmationDialog("Archive \(bankrupt) captures older than \(InboxQueue.bankruptAfterDays) days?",
                            isPresented: $confirmBankruptcy) {
            Button("Archive \(bankrupt) Captures") { Task { await store.inboxBankruptcy() } }
        } message: {
            Text("They move to Archive/Inbox/. Nothing is deleted.")
        }
        .task { await store.refreshInbox() }
    }

    private func row(_ item: InboxItem, decide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.preview.isEmpty ? item.title : item.preview).lineLimit(2)
                Spacer()
                Text(item.ageDays == 0 ? "today" : "\(item.ageDays)d")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(decide ? .orange : .secondary)
            }
            if let why = item.why, !why.isEmpty {
                Text("Why: \(why)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if decide {
                HStack(spacing: 10) {
                    Button("Note…") {
                        noteTitle = String(item.preview.prefix(60))
                        makingNote = item
                    }
                    .help("Make a note in Notes/")
                    Button("Append…") { appending = item }
                        .help("Append to an existing note, then archive")
                    Button("Archive") { Task { await store.inboxArchive(item) } }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { store.openNote(item.path) }
        .contextMenu {
            Button("Make Note…") {
                noteTitle = String(item.preview.prefix(60))
                makingNote = item
            }
            Button("Append to Note…") { appending = item }
            Button("Archive") { Task { await store.inboxArchive(item) } }
        }
    }
}

/// Picks the note a capture gets appended to.
struct AppendPicker: View {
    @Environment(VaultStore.self) private var store
    let item: InboxItem
    @State private var query = ""

    struct Choice: Identifiable {
        let path: String
        let title: String
        var id: String { path }
    }

    var choices: [Choice] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let notes = trimmed.isEmpty
            ? store.recentNotes().map { Choice(path: $0.path, title: $0.title) }
            : store.titles(matching: trimmed).map { Choice(path: $0.path, title: $0.title) }
        return notes.filter { !$0.path.hasPrefix("Inbox/") }
    }

    var body: some View {
        PickerList(placeholder: "Append “\(item.preview.prefix(40))” to…", query: $query, items: choices) { choice, _ in
            HStack {
                Text(choice.title)
                Spacer()
                Text(choice.path).font(.caption).foregroundStyle(.secondary)
            }
        } choose: { choice in
            Task { await store.inboxAppend(item, to: choice.path) }
        }
    }
}

/// Picks a folder for "Move Note to Folder…".
struct MovePicker: View {
    @Environment(VaultStore.self) private var store
    @State private var query = ""

    struct Choice: Identifiable {
        let path: String
        var id: String { path }
    }

    var choices: [Choice] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let folders = ["Notes", "Daily", "References", "Papers", "Projects", "Code", "Archive", "Private"]
            + store.folders.map(\.path)
        var seen = Set<String>()
        var result = folders.filter { seen.insert($0).inserted }
            .filter { trimmed.isEmpty || $0.lowercased().contains(trimmed) }
            .map { Choice(path: $0) }
        if !trimmed.isEmpty, !result.contains(where: { $0.path.lowercased() == trimmed }) {
            result.append(Choice(path: query.trimmingCharacters(in: .whitespaces)))
        }
        return result
    }

    var body: some View {
        PickerList(placeholder: "Move note to folder…", query: $query, items: choices) { choice, _ in
            Label(choice.path, systemImage: "folder")
        } choose: { choice in
            Task { await store.moveOpenNote(toFolder: choice.path) }
        }
    }
}
