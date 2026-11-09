import KBAI
import KBCore
import SwiftUI

/// The Sunday session: the week at a glance, four questions, your answers, and on request the
/// passages in your notes that support or complicate what you wrote.
struct WeeklyReviewView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var material = WeekMaterial(week: "")
    @State private var answers = Array(repeating: "", count: WeeklyNote.questions.count)
    @State private var index = 0
    @State private var challenge: QAAnswer?
    @State private var challenging = false
    @State private var challengeError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            week.frame(width: 220).padding(16)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weekly review · \(material.week)").font(.headline)
                    Spacer()
                    Text("\(index + 1) of \(WeeklyNote.questions.count)").foregroundStyle(.secondary).monospacedDigit()
                }
                Text(WeeklyNote.questions[index]).font(.title3)
                TextEditor(text: $answers[index]).font(.body).frame(minHeight: 140)
                    .overlay(alignment: .topLeading) {
                        if answers[index].isEmpty {
                            Text("Your words. They're what this review is judged by.").foregroundStyle(.tertiary)
                                .padding(.top, 1).padding(.leading, 5).allowsHitTesting(false)
                        }
                    }
                HStack {
                    Button("Challenge Me") { Task { await runChallenge() } }
                        .disabled(answers[index].trimmingCharacters(in: .whitespaces).count < 12 || challenging)
                        .help("Find passages in your notes that support or complicate what you wrote")
                    if challenging { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Back") { move(-1) }.disabled(index == 0)
                    if index < WeeklyNote.questions.count - 1 {
                        Button("Next") { move(1) }.keyboardShortcut(.defaultAction)
                    } else {
                        Button("Save Weekly Note") {
                            let pairs = zip(WeeklyNote.questions, answers).map { (question: $0, answer: $1) }
                            Task { await store.saveWeeklyNote(pairs) }
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(answers.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    }
                }
                challengeView
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 820, height: 600)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .task { material = store.weekMaterial() }
    }

    private var week: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("This week").font(.headline)
                LabeledContent("Notes changed", value: "\(material.changed)")
                LabeledContent("Inbox", value: "\(material.inbox)")
                LabeledContent("Open proposals", value: "\(material.proposals)")
                if !material.newClaims.isEmpty {
                    Text("New claims").font(.subheadline.weight(.semibold)).padding(.top, 4)
                    ForEach(material.newClaims) { claim in
                        Button(claim.title) { store.openNote(claim.path) }.buttonStyle(.link).lineLimit(2)
                    }
                }
                if !material.dailyNotes.isEmpty {
                    Text("Daily notes").font(.subheadline.weight(.semibold)).padding(.top, 4)
                    ForEach(material.dailyNotes, id: \.path) { note in
                        Button(note.title) { store.openNote(note.path) }.buttonStyle(.link)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var challengeView: some View {
        if let challengeError {
            Text(challengeError).font(.callout).foregroundStyle(.secondary)
        } else if let challenge {
            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.abstained ? "Your notes have nothing on this either way." : "From your notes")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(challenge.sentences.filter(\.verified).enumerated()), id: \.offset) { _, sentence in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(sentence.text)
                        if let source = sentence.sourceID.flatMap({ id in challenge.sources.first { $0.id == id } }) {
                            Button(source.hit.title) { store.openCited(source.hit, quote: sentence.quote) }
                                .buttonStyle(.link).font(.caption).help(sentence.quote ?? "")
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        }
    }

    private func move(_ step: Int) {
        index = max(0, min(WeeklyNote.questions.count - 1, index + step))
        challenge = nil
        challengeError = nil
    }

    private func runChallenge() async {
        challenging = true
        defer { challenging = false }
        do {
            challenge = try await store.challenge(answers[index], question: WeeklyNote.questions[index])
            challengeError = nil
        } catch {
            challengeError = ModelError.brief(error)
        }
    }
}
