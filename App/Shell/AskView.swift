import KBAI
import KBCore
import KBIndex
import SwiftUI

/// "Ask your notes" (⌘J): answers only from your notes, every sentence checked against its passage.
/// Socratic by default (principle 5): it asks for your view first; "Just tell me" is explicit and logged.
struct AskView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("granite.askViewFirst") private var askViewFirst = true
    @State private var question = ""
    @State private var view = ""
    @State private var stage = Stage.question
    @State private var answer: QAAnswer?
    @State private var error: String?
    @State private var qaID: Int64?
    @State private var verdict: Bool?
    @FocusState private var focus: Field?

    enum Stage { case question, view, thinking, answer }
    enum Field { case question, view }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Ask your notes…", text: $question)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focus, equals: .question)
                    .onSubmit(submitQuestion)
                Toggle("Ask my view first", isOn: $askViewFirst).toggleStyle(.checkbox).font(.caption)
            }
            if stage == .view {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you think? Your notes will be weighed against your view.").font(.callout)
                    TextField("Your view", text: $view, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focus, equals: .view)
                        .onSubmit { run(mode: .socratic) }
                    HStack {
                        Button("Answer with my view") { run(mode: .socratic) }
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(view.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Just tell me") { run(mode: .tellMe) }
                    }
                }
            }
            if stage == .thinking { ProgressView("Reading your notes…").controlSize(.small) }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            if let answer, stage == .answer { answerView(answer) }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 640, height: 480)
        .onAppear {
            focus = .question
            if let pending = AppModel.shared.shell.pendingQuestion {
                AppModel.shared.shell.pendingQuestion = nil
                question = pending
                run(mode: .tellMe)
            }
        }
        .onExitCommand { dismiss() }
    }

    private func submitQuestion() {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        answer = nil
        error = nil
        verdict = nil
        if askViewFirst {
            stage = .view
            focus = .view
        } else {
            run(mode: .tellMe)
        }
    }

    private func run(mode: QAMode) {
        stage = .thinking
        if mode == .tellMe && askViewFirst { try? store.state?.record(feature: "qa", action: .rejected, target: "tell-me") }
        Task {
            do {
                let result = try await store.ask(question, mode: mode, view: mode == .socratic ? view : nil)
                answer = result
                qaID = try? store.state?.recordQA(route: result.route?.rawValue ?? "none", mode: mode.rawValue,
                                                  abstained: result.abstained, sentences: result.sentences.count,
                                                  verified: result.verifiedCount)
                stage = .answer
            } catch {
                self.error = ModelError.brief(error)
                stage = .question
            }
        }
    }

    @ViewBuilder
    private func answerView(_ answer: QAAnswer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if answer.abstained {
                    Text("I have no note on that.").font(.title3)
                    HStack {
                        Text("Was that right?").font(.caption).foregroundStyle(.secondary)
                        Button("Yes") { mark(true) }.disabled(verdict != nil)
                        Button("No, I have a note") { mark(false) }.disabled(verdict != nil)
                    }
                    .font(.caption)
                } else {
                    ForEach(Array(answer.sentences.enumerated()), id: \.offset) { _, sentence in
                        sentenceRow(sentence, answer: answer)
                    }
                }
                if !answer.sources.isEmpty {
                    Divider()
                    Text("Sources").font(.caption).foregroundStyle(.secondary)
                    ForEach(answer.sources, id: \.id) { source in
                        Button {
                            store.openNote(source.hit.path, line: source.hit.startLine)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(source.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(source.hit.title)
                                Text(source.hit.origin).font(.caption2).padding(.horizontal, 4)
                                    .background(.quaternary, in: Capsule())
                                Spacer()
                                Text("\(source.hit.path):\(source.hit.startLine)").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(footer(answer)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func sentenceRow(_ sentence: AnswerSentence, answer: QAAnswer) -> some View {
        let source = sentence.sourceID.flatMap { id in answer.sources.first { $0.id == id } }
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(sentence.text)
                .foregroundStyle(sentence.verified ? .primary : .secondary)
                .strikethrough(!sentence.verified, color: .secondary)
            if sentence.verified, let source {
                Button(source.id) { store.openNote(source.hit.path, line: source.hit.startLine) }
                    .buttonStyle(.link).font(.caption)
                    .help(sentence.quote ?? "")
            } else {
                Text("unsupported").font(.caption2).foregroundStyle(.orange)
                    .help("The quote couldn't be found in the cited passage, so this isn't shown as fact.")
            }
        }
    }

    private func footer(_ answer: QAAnswer) -> String {
        var parts = ["\(answer.route?.rawValue ?? "no model") · \(answer.label.rawValue) notes"]
        if !answer.abstained { parts.append("\(answer.verifiedCount)/\(answer.sentences.count) sentences verified") }
        if let notice = answer.notice { parts.append(notice) }
        return parts.joined(separator: " · ")
    }

    private func mark(_ correct: Bool) {
        verdict = correct
        if let qaID { try? store.state?.markAbstention(qaID: qaID, correct: correct) }
    }
}
