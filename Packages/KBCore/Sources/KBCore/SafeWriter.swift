import CryptoKit
import Foundation

/// Who is writing. AI writers may only touch `AI/` (principle 3); this is enforced here, in code.
public enum WriterRole: Sendable {
    /// The user acting through granite's UI or CLI.
    case user
    /// Any model or agent. Writes outside `AI/` must become proposals instead.
    case ai
}

public enum SafeWriteError: Error, Equatable, CustomStringConvertible {
    case outsideVault(String)
    case forbiddenPath(String)
    case aiWriteOutsideAI(String)
    case coordination(String)
    case destinationExists(String)
    case missing(String)

    public var description: String {
        switch self {
        case .outsideVault(let path): "refusing to write outside the vault: \(path)"
        case .forbiddenPath(let path): "granite never writes here: \(path)"
        case .aiWriteOutsideAI(let path): "AI may only write under AI/; propose a change instead: \(path)"
        case .coordination(let message): "file coordination failed: \(message)"
        case .destinationExists(let path): "a file already exists at \(path)"
        case .missing(let path): "no file at \(path)"
        }
    }
}

/// The only path for granite's own writes into a vault.
/// Writes are coordinated (so Obsidian, iCloud and other presenters see them) and atomic,
/// and their hashes are remembered so the FSEvents echo of our own write is ignored.
public actor SafeWriter {
    public let vault: Vault
    private let echoWindow: TimeInterval
    private var recent: [String: [(hash: Data, at: Date)]] = [:]

    public init(vault: Vault, echoWindow: TimeInterval = 10) {
        self.vault = vault
        self.echoWindow = echoWindow
    }

    /// Writes `data` to a vault-relative path, creating folders as needed.
    public func write(_ data: Data, to path: String, as role: WriterRole) throws {
        let clean = try validate(path, role: role)
        let url = vault.url(for: clean)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let coordinationError { throw SafeWriteError.coordination(coordinationError.localizedDescription) }
        if let writeError { throw writeError }
        remember(path: clean, hash: Data(SHA256.hash(data: data)))
    }

    /// Moves or renames a file inside the vault. Coordinated, creates folders, never overwrites.
    public func move(from source: String, to destination: String, as role: WriterRole) throws {
        let from = try validate(source, role: role)
        let to = try validate(destination, role: role)
        let fromURL = vault.url(for: from)
        let toURL = vault.url(for: to)
        let manager = FileManager.default
        guard manager.fileExists(atPath: fromURL.path(percentEncoded: false)) else { throw SafeWriteError.missing(from) }
        // A case-only rename ("note.md" → "Note.md") is the same file on a case-insensitive volume.
        let caseOnly = from.lowercased() == to.lowercased() && from != to
        guard caseOnly || !manager.fileExists(atPath: toURL.path(percentEncoded: false)) else {
            throw SafeWriteError.destinationExists(to)
        }
        try manager.createDirectory(at: toURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var coordinationError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: fromURL, options: .forMoving, writingItemAt: toURL, options: .forReplacing,
                               error: &coordinationError) { sourceURL, targetURL in
            do {
                try manager.moveItem(at: sourceURL, to: targetURL)
                coordinator.item(at: sourceURL, didMoveTo: targetURL)
            } catch {
                moveError = error
            }
        }
        if let coordinationError { throw SafeWriteError.coordination(coordinationError.localizedDescription) }
        if let moveError { throw moveError }
    }

    public func write(_ text: String, to path: String, as role: WriterRole) throws {
        try write(Data(text.utf8), to: path, as: role)
    }

    /// True if a change event for `path` with this content hash is the echo of our own write.
    /// Each remembered write is consumed once.
    public func isEcho(path: String, hash: Data) -> Bool {
        prune()
        guard var entries = recent[path], let match = entries.firstIndex(where: { $0.hash == hash }) else { return false }
        entries.remove(at: match)
        recent[path] = entries.isEmpty ? nil : entries
        return true
    }

    private func remember(path: String, hash: Data) {
        prune()
        recent[path, default: []].append((hash, Date()))
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-echoWindow)
        recent = recent.compactMapValues { entries in
            let kept = entries.filter { $0.at >= cutoff }
            return kept.isEmpty ? nil : kept
        }
    }

    /// Normalizes a vault-relative path and applies the write rules.
    nonisolated public func validate(_ path: String, role: WriterRole) throws -> String {
        var parts: [String] = []
        for part in path.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." { continue }
            if part == ".." { throw SafeWriteError.outsideVault(path) }
            parts.append(String(part))
        }
        guard !parts.isEmpty, !path.hasPrefix("/") else { throw SafeWriteError.outsideVault(path) }
        let clean = parts.joined(separator: "/")
        let first = parts[0].lowercased()
        if first == ".obsidian" || first == ".git" { throw SafeWriteError.forbiddenPath(clean) }
        if role == .ai && (first != "ai" || parts.count < 2) { throw SafeWriteError.aiWriteOutsideAI(clean) }
        return clean
    }
}
