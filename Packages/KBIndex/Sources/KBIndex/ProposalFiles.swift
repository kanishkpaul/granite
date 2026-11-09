import Foundation
import KBCore

/// Proposal files without the index, for writers in another process (granite-mcp, Claude Code):
/// the same cap and duplicate rules as `ProposalStore`, read straight from `AI/Proposals/`.
/// The app's watcher indexes what they write.
public enum ProposalFiles {
    public static func all(in vault: Vault) -> [Proposal] {
        let folder = vault.url(for: ProposalStore.folder)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasSuffix(".md") }.compactMap { name in
            let path = "\(ProposalStore.folder)/\(name)"
            guard let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { return nil }
            return Proposal.parse(text, path: path)
        }
    }

    /// Writes an open proposal as AI. Throws `queueFull` or `duplicate` like the in-app store.
    public static func write(_ proposal: Proposal, vault: Vault, writer: SafeWriter, now: Date = Date(),
                             calendar: Calendar = .current) async throws -> String {
        let existing = all(in: vault)
        guard existing.filter({ $0.status == .open }).count < ProposalStore.cap else { throw ProposalStoreError.queueFull(ProposalStore.cap) }
        if let duplicate = existing.first(where: { $0.status != .accepted && $0.status != .edited && $0.kind == proposal.kind
            && ProposalStore.sameTarget($0.target, proposal.target) && $0.change == proposal.change }) {
            throw ProposalStoreError.duplicate(duplicate.path ?? "")
        }
        var proposal = proposal
        proposal.status = .open
        proposal.rationale = proposal.rationale.replacingOccurrences(of: "\n", with: " ")
        if proposal.created.isEmpty { proposal.created = ProposalStore.day(now, calendar) }
        let base = Proposal.fileName(kind: proposal.kind, target: proposal.target, stamp: ProposalStore.stamp(now, calendar))
        var path = base
        var suffix = 2
        while FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) {
            path = String(base.dropLast(3)) + " \(suffix).md"
            suffix += 1
        }
        try await writer.write(proposal.render(), to: path, as: .ai)
        return path
    }
}
