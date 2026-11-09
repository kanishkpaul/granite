import Foundation
import KBCore
import KBIndex
import SwiftUI

/// Walking a trail: which trail, and which step you're on.
struct TrailWalk: Equatable {
    let path: String
    let trail: Trail
    var index: Int
}

/// Trails in the app (master plan §7, idea 10): walk one step by step; candidate trails come as
/// proposals from your link chains or from a Q&A's sources, and count once you've named them.
extension VaultStore {
    static let trailsFolder = "Notes/Trails"

    func openTrail() -> Trail? {
        guard let path = openPath, let vault, let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { return nil }
        return Trail.parse(text, path: path)
    }

    func startWalk() {
        guard let path = openPath, let trail = openTrail(), !trail.steps.isEmpty else { return }
        trailWalk = TrailWalk(path: path, trail: trail, index: 0)
        openStep(0)
    }

    func stepWalk(_ delta: Int) {
        guard var walk = trailWalk else { return }
        walk.index = max(0, min(walk.trail.steps.count - 1, walk.index + delta))
        trailWalk = walk
        openStep(walk.index)
    }

    func endWalk() {
        if let walk = trailWalk { openNote(walk.path) }
        trailWalk = nil
    }

    private func openStep(_ index: Int) {
        guard let walk = trailWalk, walk.trail.steps.indices.contains(index), let database else { return }
        let target = walk.trail.steps[index].target
        let base = String(target.split(separator: "#").first ?? Substring(target))
        if let path = try? database.resolve(linkTarget: base, from: walk.path) {
            openNote(path)
        } else {
            status = "No note named “\(base)” yet."
        }
    }

    /// Candidate trails from chains of linked notes changed in the last month.
    func suggestTrails() async {
        guard let database, let proposalStore else { return }
        let chains = (try? TrailSuggester.chains(in: database, since: Date().addingTimeInterval(-30 * 86_400))) ?? []
        var created = 0
        for chain in chains {
            let title = "Trail from \(NoteParser.title(for: chain[0]))"
            if await proposeTrail(title: title, targets: chain.map { String($0.dropLast(3)) }, source: "your links", store: proposalStore) {
                created += 1
            }
        }
        status = created == 0 ? "No new trail candidates (needs chains of three linked notes)." : "Proposed \(created) trail(s): see Proposals."
        await refreshProposals()
    }

    /// From an answer's cited notes, in the order the answer used them.
    func trailFromAnswer(question: String, paths: [String]) async {
        guard let proposalStore else { return }
        var seen = Set<String>()
        let ordered = paths.filter { seen.insert($0).inserted }.filter { !$0.hasPrefix("AI/") }
        guard ordered.count >= 2 else {
            status = "A trail needs at least two notes."
            return
        }
        let title = "Trail: " + String(question.prefix(60))
        if await proposeTrail(title: title, targets: ordered.map { String($0.dropLast(3)) }, source: "the question “\(question.prefix(80))”",
                              store: proposalStore) {
            status = "Trail proposed: name it and write a sentence per step in Proposals."
            await refreshProposals()
        }
    }

    private func proposeTrail(title: String, targets: [String], source: String, store: ProposalStore) async -> Bool {
        let date = ClaimDay.string(Date())
        let path = "\(Self.trailsFolder)/\(NoteFileName.make(title)).md"
        let proposal = Proposal(kind: .trail, target: path, feature: "trails", model: "none",
                                rationale: "These notes link in this order (\(source)). A trail counts once you name it and write why each step follows.",
                                change: ProposalChange(added: Trail.candidate(title: title, targets: targets, date: date, source: source)),
                                created: date)
        return (try? await store.create(proposal)) != nil
    }
}

/// Inspector: the open trail's steps, or where you are on the trail you're walking.
struct TrailInspectorSection: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        if let walk = store.trailWalk {
            Section("Walking: \(walk.trail.title)") {
                Text("Step \(walk.index + 1) of \(walk.trail.steps.count)").font(.caption).foregroundStyle(.secondary)
                let step = walk.trail.steps[walk.index]
                Text(step.sentence.isEmpty ? "(no sentence yet)" : step.sentence).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Back") { store.stepWalk(-1) }.disabled(walk.index == 0)
                    Button("Next") { store.stepWalk(1) }.disabled(walk.index + 1 >= walk.trail.steps.count)
                    Spacer()
                    Button("End") { store.endWalk() }
                }
            }
        } else if let trail = store.openTrail() {
            Section("Trail · \(trail.steps.count) steps\(trail.endorsed ? "" : " · candidate")") {
                ForEach(Array(trail.steps.enumerated()), id: \.offset) { index, step in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(index + 1). \(step.target)")
                        if !step.sentence.isEmpty { Text(step.sentence).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Button("Walk This Trail", systemImage: "figure.walk") { store.startWalk() }.disabled(trail.steps.isEmpty)
            }
        }
    }
}
