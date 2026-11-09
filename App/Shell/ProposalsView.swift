import KBCore
import KBIndex
import SwiftUI

/// The proposal queue (master plan §6.4): every AI change to a note outside AI/ waits here.
/// A accepts, E edits then accepts, R rejects; each decision goes to AI/log.md.
struct ProposalsView: View {
    @Environment(VaultStore.self) private var store
    @State private var selection: String?
    @State private var editing: Proposal?
    @FocusState private var focused: Bool

    private var selected: Proposal? {
        store.openProposals.first { $0.path == selection } ?? store.openProposals.first
    }

    var body: some View {
        VStack(spacing: 0) {
            List(store.openProposals, id: \.path, selection: $selection) { proposal in
                ProposalRow(proposal: proposal).tag(proposal.path)
            }
            .focused($focused)
            .onKeyPress(characters: CharacterSet(charactersIn: "aer")) { press in
                guard let proposal = selected else { return .ignored }
                switch press.characters {
                case "a": Task { await store.decide(proposal, .accept) }
                case "r": Task { await store.decide(proposal, .reject) }
                default: editing = proposal
                }
                return .handled
            }
            .overlay {
                if store.openProposals.isEmpty {
                    ContentUnavailableView("No proposals", systemImage: "checkmark.seal",
                                           description: Text("AI suggestions for your notes wait here until you decide."))
                }
            }
            if let proposal = selected {
                Divider()
                ProposalDetail(proposal: proposal, edit: { editing = proposal })
            }
            footer
        }
        .sheet(item: Binding(get: { editing.map(EditingProposal.init) }, set: { editing = $0?.proposal })) { item in
            ProposalEditor(proposal: item.proposal) { change in
                Task { await store.decide(item.proposal, .edit(change)) }
            }
        }
        .task {
            await store.refreshProposals()
            focused = true
        }
    }

    private var footer: some View {
        HStack {
            Text("\(store.openProposals.count) of \(ProposalStore.cap) open").monospacedDigit()
            if !store.pausedFeatures.isEmpty {
                Text("· paused: \(store.pausedFeatures.joined(separator: ", "))")
                    .help("Under 10% of these suggestions were accepted in the last four weeks.")
            }
            Spacer()
            Button("Suggest Links") { Task { await store.suggestLinks() } }
                .buttonStyle(.link)
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

private struct EditingProposal: Identifiable {
    let proposal: Proposal
    var id: String { proposal.path ?? "" }
}

struct ProposalRow: View {
    let proposal: Proposal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(proposal.kind.rawValue.capitalized).font(.caption.weight(.semibold))
                    .padding(.horizontal, 5).background(.quaternary, in: .capsule)
                Text(Self.display(proposal.target)).lineLimit(1).help(proposal.target)
                Spacer()
                Text(proposal.feature).font(.caption2).foregroundStyle(.tertiary)
            }
            Text(proposal.change.added.first ?? proposal.change.removed.first ?? "")
                .font(.callout.monospaced()).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    /// "[[Notes/Hybrid retrieval]]" → "Hybrid retrieval".
    static func display(_ target: String) -> String {
        var text = target
        if text.hasPrefix("[["), text.hasSuffix("]]") { text = String(text.dropFirst(2).dropLast(2)) }
        text = String(text.split(separator: "|").first ?? Substring(text))
        if text.hasSuffix(".md") { text = String(text.dropLast(3)) }
        return String(text.split(separator: "/").last ?? Substring(text))
    }
}

struct ProposalDetail: View {
    @Environment(VaultStore.self) private var store
    let proposal: Proposal
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(proposal.rationale).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(proposal.change.removed.enumerated()), id: \.offset) { _, line in
                    Text("− " + line).foregroundStyle(.red)
                }
                ForEach(Array(proposal.change.added.enumerated()), id: \.offset) { _, line in
                    Text("+ " + line).foregroundStyle(.green)
                }
            }
            .font(.callout.monospaced())
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
            HStack(spacing: 4) {
                Text("by \(proposal.model)")
                if let label = proposal.label { Text("· \(label.rawValue)") }
                if !proposal.citations.isEmpty { Text("· cites \(proposal.citations.joined(separator: ", "))").lineLimit(1) }
            }
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Accept") { Task { await store.decide(proposal, .accept) } }
                    .help("A")
                Button("Edit…", action: edit).help("E")
                Button("Reject") { Task { await store.decide(proposal, .reject) } }
                    .help("R")
                Spacer()
                if let target = store.targetPath(of: proposal) {
                    Button("Open Note") { store.openNote(target) }.buttonStyle(.link)
                }
            }
        }
        .padding(10)
    }
}

/// Edit the lines a proposal adds (and, for edits, check what it removes) before accepting.
private struct ProposalEditor: View {
    @Environment(\.dismiss) private var dismiss
    let proposal: Proposal
    let accept: (ProposalChange) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit before accepting").font(.headline)
            if !proposal.change.removed.isEmpty {
                Text("Replaces:").font(.caption).foregroundStyle(.secondary)
                Text(proposal.change.removed.joined(separator: "\n")).font(.callout.monospaced()).foregroundStyle(.red)
            }
            Text(proposal.change.removed.isEmpty ? "Adds:" : "With:").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.callout.monospaced()).frame(minHeight: 120)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Accept Edited") {
                    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                    accept(ProposalChange(removed: proposal.change.removed, added: lines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 520)
        .onAppear { text = proposal.change.added.joined(separator: "\n") }
    }
}
