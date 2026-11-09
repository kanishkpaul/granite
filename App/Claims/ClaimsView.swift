import KBCore
import KBIndex
import SwiftUI

/// Every claim by status: what you hold now, what you're revising, and what you've moved past.
struct ClaimsView: View {
    @Environment(VaultStore.self) private var store
    @State private var filter = ""

    private let order: [ClaimStatus] = [.held, .proposed, .revised, .superseded, .retired]

    private var filtered: [ClaimRecord] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return store.claims }
        return store.claims.filter { $0.title.lowercased().contains(query) || $0.tags.contains { $0.lowercased().contains(query) } }
    }

    var body: some View {
        List {
            ForEach(order, id: \.self) { status in
                let group = filtered.filter { $0.status == status }
                if !group.isEmpty {
                    Section("\(status.rawValue.capitalized) · \(group.count)") {
                        ForEach(group) { claim in row(claim) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            TextField("Filter claims or tags", text: $filter)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 10).padding(.top, 6)
        }
        .overlay {
            if store.claims.isEmpty {
                ContentUnavailableView("No claims yet", systemImage: "checkmark.seal",
                                       description: Text("Put the cursor on a sentence you believe and choose Promote to Claim (⌥⌘P)."))
            }
        }
        .task { await store.refreshClaims() }
    }

    private func row(_ claim: ClaimRecord) -> some View {
        Button {
            store.openNote(claim.path)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(claim.title).lineLimit(2)
                    .strikethrough(claim.status == .superseded || claim.status == .retired, color: .secondary)
                HStack(spacing: 8) {
                    if let confidence = claim.confidence { Text("\(Int(confidence * 100))%").monospacedDigit() }
                    if let asOf = claim.asOf { Text(asOf) }
                    if !claim.tags.isEmpty { Text(claim.tags.map { "#\($0)" }.joined(separator: " ")) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(store.openPath == claim.path ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}

/// Inspector section for an open claim: status, supersede, and the chain it belongs to.
struct ClaimInspectorSection: View {
    @Environment(VaultStore.self) private var store
    let path: String
    @Binding var superseding: Bool
    @State private var history: [ClaimRecord] = []

    var body: some View {
        Section("Claim") {
            if let claim = store.claims.first(where: { $0.path == path }) {
                LabeledContent("Status") {
                    Menu(claim.status.rawValue.capitalized) {
                        ForEach([ClaimStatus.held, .revised, .retired], id: \.self) { status in
                            Button(status.rawValue.capitalized) { Task { await store.setClaimStatus(status) } }
                        }
                    }
                    .fixedSize()
                }
                if let asOf = claim.asOf { LabeledContent("As of", value: asOf) }
            }
            Button("Supersede…", systemImage: "arrow.triangle.branch") { superseding = true }
        }
        if history.count > 1 {
            Section("History") {
                ForEach(history) { claim in
                    Button {
                        store.openNote(claim.path)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: claim.path == path ? "circle.fill" : "circle").font(.caption2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(claim.title).lineLimit(2)
                                Text("\(claim.status.rawValue) · \(claim.asOf ?? "")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        EmptyView().task(id: path + "\(store.claims.count)") { history = await store.claimHistory(of: path) }
    }
}

/// Promote (new claim citing the selection) or supersede (new claim replacing the open one).
struct ClaimSheet: View {
    enum Mode { case promote(line: Int), supersede }
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State var text: String
    @State private var confidence = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch mode {
            case .promote:
                Text("Promote to claim").font(.headline)
                Text("One assertion you hold. It cites the paragraph it came from.").font(.callout).foregroundStyle(.secondary)
            case .supersede:
                Text("Supersede this claim").font(.headline)
                Text("Write what you think now. The old claim keeps its text and is marked superseded.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            TextEditor(text: $text).font(.body).frame(minHeight: 90)
            HStack {
                Text("Confidence")
                Slider(value: $confidence, in: 0...1, step: 0.05)
                Text("\(Int(confidence * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isPromote ? "Promote" : "Supersede") {
                    let value = text, level = confidence
                    Task {
                        switch mode {
                        case .promote(let line): await store.promoteToClaim(value, line: line, confidence: level)
                        case .supersede: await store.supersedeOpenClaim(with: value, confidence: level)
                        }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 520)
    }

    private var isPromote: Bool {
        if case .promote = mode { return true }
        return false
    }
}
