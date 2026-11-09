import KBCore
import KBReview
import SwiftUI

/// The daily review: question first; recall, then reveal and grade (1–4). Space reveals.
struct ReviewView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [DuePrompt] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var shownAt = Date()
    @State private var reviewed = 0
    @State private var recalled = 0
    @State private var loading = true
    @FocusState private var focused: Bool

    private var current: DuePrompt? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Review").font(.headline)
                Spacer()
                if !queue.isEmpty { Text("\(min(index + 1, queue.count)) of \(queue.count)").monospacedDigit().foregroundStyle(.secondary) }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if let current {
                card(current)
            } else {
                summary
            }
        }
        .padding(20)
        .frame(width: 560, height: 420, alignment: .top)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(characters: CharacterSet(charactersIn: " 1234")) { press in
            guard let current else { return .ignored }
            if press.characters == " " {
                revealed = true
                return .handled
            }
            guard revealed, let value = Int(press.characters), let grade = Grade(rawValue: value) else { return .ignored }
            Task { await answer(current, grade) }
            return .handled
        }
        .task {
            queue = await store.duePrompts()
            loading = false
            shownAt = Date()
            focused = true
        }
    }

    private func card(_ item: DuePrompt) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.prompt.question).font(.title3).fixedSize(horizontal: false, vertical: true)
            Text(NoteParser.title(for: item.prompt.path) + (item.card == nil ? " · new" : ""))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            if revealed {
                ScrollView {
                    Text(item.prompt.answer.isEmpty ? "(no answer written)" : item.prompt.answer)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                let previews = store.intervals(for: item.card)
                HStack {
                    ForEach(Grade.allCases, id: \.self) { grade in
                        Button {
                            Task { await answer(item, grade) }
                        } label: {
                            VStack(spacing: 1) {
                                Text(label(grade))
                                Text(previews[grade] ?? "").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .help("\(grade.rawValue)")
                    }
                }
                Button("Open note") { store.openNote(item.prompt.path, line: item.prompt.line) }.buttonStyle(.link).font(.caption)
            } else {
                Text("Recall the answer, then reveal it.").foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Show Answer") { revealed = true }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.secondary)
            Text(reviewed == 0 ? "Nothing due. Add prompts with > [!prompt] in a note, or ⌘K “Make prompts”." : "Done for now.")
                .multilineTextAlignment(.center)
            if reviewed > 0 {
                Text("Reviewed \(reviewed) · recalled \(Int(Double(recalled) / Double(reviewed) * 100))%")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func label(_ grade: Grade) -> String {
        switch grade {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    private func answer(_ item: DuePrompt, _ grade: Grade) async {
        let next = await store.grade(item.prompt, grade, seconds: Date().timeIntervalSince(shownAt))
        reviewed += 1
        if grade != .again { recalled += 1 }
        if grade == .again {
            // Lapses come back at the end of this session.
            queue.append(DuePrompt(prompt: item.prompt, card: next))
        }
        index += 1
        revealed = false
        shownAt = Date()
        if index >= queue.count { await store.refreshDue() }
    }
}
