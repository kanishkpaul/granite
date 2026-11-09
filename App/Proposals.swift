import Foundation
import KBAI
import KBCore
import KBIndex

/// The proposal queue in the app: list, decide, and the see-also job that fills it.
extension VaultStore {
    static let seeAlsoLastRunKey = "granite.seeAlso.lastRun"

    func refreshProposals() async {
        guard let proposalStore else {
            openProposals = []
            return
        }
        openProposals = (try? await proposalStore.open()) ?? []
        var paused: [String] = []
        for feature in [SeeAlsoJob.feature] where (try? await proposalStore.isPaused(feature: feature)) == true {
            paused.append(feature)
        }
        pausedFeatures = paused
    }

    func decide(_ proposal: Proposal, _ decision: ProposalDecision) async {
        guard let proposalStore, let path = proposal.path else { return }
        do {
            try await proposalStore.decide(path, decision)
            status = switch decision {
            case .reject: "Rejected: \(proposal.kind.rawValue) for \(proposal.target)"
            default: "Applied to \(proposal.target)"
            }
        } catch {
            status = "Could not apply: \(error)"
        }
        refreshLists()
        await refreshProposals()
    }

    /// The note a proposal changes, for "Open target".
    func targetPath(of proposal: Proposal) -> String? {
        if proposal.createsNote { return nil }
        var target = proposal.target
        if target.hasPrefix("[["), target.hasSuffix("]]") { target = String(target.dropFirst(2).dropLast(2)) }
        target = String(target.split(separator: "|").first ?? "")
        target = String(target.split(separator: "#").first ?? "")
        return try? database?.resolve(linkTarget: target, from: proposal.path ?? "")
    }

    /// Runs see-also about a minute after a vault opens, at most once every 20 hours.
    func scheduleSeeAlso() {
        proposalTask?.cancel()
        proposalTask = Task {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            let last = UserDefaults.standard.object(forKey: Self.seeAlsoLastRunKey) as? Date ?? .distantPast
            if Date().timeIntervalSince(last) > 20 * 3600 { await suggestLinks() }
        }
    }

    /// Proposes links for notes changed in the last week (palette: "Suggest links").
    func suggestLinks() async {
        guard let database, let proposalStore, let vault else { return }
        UserDefaults.standard.set(Date(), forKey: Self.seeAlsoLastRunKey)
        let since = Date().addingTimeInterval(-7 * 86_400)
        let paths = ((try? database.recent(limit: 40, since: since)) ?? [])
            .filter { SeeAlsoJob.eligible(path: $0.path, type: $0.type, aiLabel: $0.aiLabel) }
            .map(\.path)
        guard !paths.isEmpty else {
            status = "No notes changed this week to suggest links for."
            return
        }
        let searcher = semantic.hasVectors ? semantic.searcher : nil
        let finder = RelatedFinder(database: database, vectors: searcher?.vectors, embedder: searcher?.embedder)
        let job = SeeAlsoJob(finder: finder, store: proposalStore, justify: models.map { Self.linkReason(models: $0, vault: vault, policy: policy) })
        do {
            let created = try await job.run(paths: paths)
            status = created.isEmpty ? "No new links to suggest." : "Suggested \(created.count) link(s): see Proposals."
        } catch {
            status = "Link suggestions failed: \(error)"
        }
        await refreshProposals()
        refreshLists()
    }

    /// One sentence on why the notes belong together, from the model the labels allow (on-device first).
    nonisolated static func linkReason(models: ModelService, vault: Vault, policy: VaultPolicy) -> SeeAlsoJob.Justify {
        { notePath, candidate in
            guard let data = try? Data(contentsOf: vault.url(for: notePath)) else { return nil }
            let body = MarkdownDocument(text: String(decoding: data, as: UTF8.self)).bodyLines.map(\.text)
                .joined(separator: "\n").prefix(1_200)
            let note = NoteParser.parse(data: data, path: notePath, policy: policy)
            let labels = [note.aiLabel] + [AILabel(rawValue: candidate.aiLabel) ?? .local]
            let request = GenerationRequest(
                system: """
                    You explain in one short sentence (under 25 words) why one note should link to another. \
                    Use only the text given. No preamble, no quotes around the sentence.
                    """,
                prompt: """
                    Note "\(note.title)":
                    \(body)

                    Candidate note "\(candidate.title)" (\(candidate.reason == .mention ? "named in the note" : "similar passage")):
                    \(candidate.snippet)
                    """,
                maxTokens: 80)
            guard let result = try? await models.run(.linkReason, labels: labels, notePaths: [notePath, candidate.path],
                                                     request: request, interactive: false) else { return nil }
            let sentence = result.generation.text.split(separator: "\n").first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))) ?? ""
            guard sentence.count > 8 else { return nil }
            return (String(sentence.prefix(240)), result.route.rawValue)
        }
    }
}
