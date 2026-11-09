import Foundation
import KBCore
import KBIndex

/// The claim ledger in the app: promote the selection, supersede, set status, read the history.
extension VaultStore {
    func refreshClaims() async {
        claims = (try? await claimService?.claims()) ?? []
    }

    /// The selected text in the editor, or the paragraph at the cursor, and the line to cite.
    func selectionForClaim() -> (text: String, line: Int)? {
        guard let path = openPath, let vault, let data = try? Data(contentsOf: vault.url(for: path)) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        let utf16 = Array(text.utf16)
        let from = min(cursor, selectionAnchor), to = max(cursor, selectionAnchor)
        if to > from, to <= utf16.count {
            let selected = String(decoding: utf16[from..<to], as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !selected.isEmpty { return (selected, cursorLine) }
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.indices.contains(cursorLine - 1) else { return nil }
        var line = String(lines[cursorLine - 1]).trimmingCharacters(in: .whitespaces)
        // Strip list and quote markers and a trailing block id.
        line = line.replacingOccurrences(of: #"^([-*+]|\d+[.)]|>)\s+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\s\^[A-Za-z0-9-]+$"#, with: "", options: .regularExpression)
        return line.isEmpty ? nil : (line, cursorLine)
    }

    func promoteToClaim(_ text: String, line: Int, confidence: Double) async {
        guard let claimService, let path = openPath else { return }
        do {
            let claim = try await claimService.promote(text, from: path, line: line, confidence: confidence)
            status = "Promoted to \(claim)"
            refreshLists()
            await refreshClaims()
            openNote(claim)
        } catch {
            status = "Could not promote: \(error)"
        }
    }

    func supersedeOpenClaim(with text: String, confidence: Double) async {
        guard let claimService, let path = openPath else { return }
        do {
            let claim = try await claimService.supersede(path, with: text, confidence: confidence)
            status = "\(NoteParser.title(for: path)) is superseded by \(NoteParser.title(for: claim))"
            refreshLists()
            await refreshClaims()
            openNote(claim)
        } catch {
            status = "Could not supersede: \(error)"
        }
    }

    func setClaimStatus(_ claimStatus: ClaimStatus) async {
        guard let claimService, let path = openPath else { return }
        do {
            try await claimService.setStatus(claimStatus, of: path)
            status = "Marked \(claimStatus.rawValue)"
            await refreshClaims()
            refreshInspector()
        } catch {
            status = "Could not change the status: \(error)"
        }
    }

    func claimHistory(of path: String) async -> [ClaimRecord] {
        (try? await claimService?.history(of: path)) ?? []
    }

    var openNoteIsClaim: Bool {
        guard let path = openPath else { return false }
        return claims.contains { $0.path == path }
    }

    /// The body text of a claim (for prefilling "Supersede").
    func claimText(_ path: String) -> String {
        guard let vault, let data = try? Data(contentsOf: vault.url(for: path)) else { return "" }
        return MarkdownDocument(text: String(decoding: data, as: UTF8.self)).bodyLines.map(\.text).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
