import Foundation
import GRDB
import KBCore

public enum ProposalStoreError: Error, Equatable, CustomStringConvertible {
    case queueFull(Int)
    case paused(String)
    case duplicate(String)
    case notFound(String)
    case alreadyDecided(String)

    public var description: String {
        switch self {
        case .queueFull(let cap): "the proposal queue is full (\(cap) open); decide some first"
        case .paused(let feature): "\(feature) is paused: under 10% of its proposals were accepted"
        case .duplicate(let path): "the same change is already proposed or was rejected: \(path)"
        case .notFound(let path): "no proposal at \(path)"
        case .alreadyDecided(let path): "already decided: \(path)"
        }
    }
}

public enum ProposalDecision: Sendable, Equatable {
    case accept
    /// Accept a changed version: the edited diff is kept in the proposal file.
    case edit(ProposalChange)
    case reject
}

/// The proposal queue (master plan §6.4). Every AI change to a note outside `AI/` goes through here:
/// written as a file under `AI/Proposals/`, applied only when you accept it, and logged to `AI/log.md`.
public actor ProposalStore {
    public static let folder = "AI/Proposals"
    public static let logPath = "AI/log.md"
    /// At most this many open proposals; feature jobs stop proposing when it is reached.
    public static let cap = 25
    /// A feature pauses when under this share of its proposals is accepted (over `pauseWindow`, at least `pauseMinimum` shown).
    public static let pauseBelow = FeatureGuard.pauseBelow
    public static let pauseWindow = FeatureGuard.window
    public static let pauseMinimum = FeatureGuard.minimumShown

    public let indexer: Indexer
    let writer: SafeWriter
    let state: StateDatabase?
    let calendar: Calendar

    public init(indexer: Indexer, writer: SafeWriter, state: StateDatabase?, calendar: Calendar = .current) {
        self.indexer = indexer
        self.writer = writer
        self.state = state
        self.calendar = calendar
    }

    var database: IndexDatabase { indexer.database }
    var vault: Vault { indexer.vault }

    // MARK: Reading

    /// Every proposal file under `AI/Proposals/`, parsed, newest first.
    public func all() async throws -> [Proposal] {
        let paths = try await database.pool.read { db in
            try String.fetchAll(db, sql: "SELECT path FROM objects WHERE type = 'proposal' AND path LIKE ? ORDER BY path DESC",
                                arguments: [Self.folder + "/%"])
        }
        return paths.compactMap { path in
            guard let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) else { return nil }
            return Proposal.parse(text, path: path)
        }
    }

    public func open() async throws -> [Proposal] {
        try await all().filter { $0.status == .open }
    }

    public func openCount() async throws -> Int {
        try await database.pool.read { db in
            try Int.fetchOne(db, sql: """
                SELECT count(*) FROM objects WHERE type = 'proposal' AND path LIKE ? AND coalesce(status, 'open') = 'open'
                """, arguments: [Self.folder + "/%"]) ?? 0
        }
    }

    /// Paused when the last four weeks show at least 20 proposals and under 10% accepted or edited.
    public func isPaused(feature: String, now: Date = Date()) throws -> Bool {
        try state?.isPaused(feature: feature, now: now) ?? false
    }

    // MARK: Writing

    /// Writes a new open proposal (as the AI role, so only under `AI/`) and indexes it. Returns its path.
    @discardableResult
    public func create(_ proposal: Proposal, now: Date = Date()) async throws -> String {
        if try isPaused(feature: proposal.feature, now: now) { throw ProposalStoreError.paused(proposal.feature) }
        let openCount = try await openCount()
        guard openCount < Self.cap else { throw ProposalStoreError.queueFull(Self.cap) }
        for existing in try await all() where existing.status != .accepted && existing.status != .edited
            && existing.kind == proposal.kind && Self.sameTarget(existing.target, proposal.target)
            && existing.change == proposal.change {
            throw ProposalStoreError.duplicate(existing.path ?? "")
        }

        var proposal = proposal
        proposal.status = .open
        proposal.decided = nil
        proposal.rationale = proposal.rationale.replacingOccurrences(of: "\n", with: " ")
        if proposal.created.isEmpty { proposal.created = Self.day(now, calendar) }
        let base = Proposal.fileName(kind: proposal.kind, target: proposal.target, stamp: Self.stamp(now, calendar))
        var path = base
        var suffix = 2
        while FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) {
            path = String(base.dropLast(3)) + " \(suffix).md"
            suffix += 1
        }
        try await writer.write(proposal.render(), to: path, as: .ai)
        _ = try await indexer.update(paths: [path])
        try state?.record(feature: proposal.feature, action: .shown, target: path, date: now)
        return path
    }

    /// Accepts, edits or rejects an open proposal. Accepting applies the change to the target note
    /// (as the user: you made the decision); a conflict leaves everything untouched and throws.
    public func decide(_ path: String, _ decision: ProposalDecision, now: Date = Date()) async throws {
        let url = vault.url(for: path)
        guard path.hasPrefix(Self.folder + "/"), let text = try? String(contentsOf: url, encoding: .utf8),
              var proposal = Proposal.parse(text, path: path) else { throw ProposalStoreError.notFound(path) }
        guard proposal.status == .open else { throw ProposalStoreError.alreadyDecided(path) }

        var touched = [path]
        let status: ProposalStatus
        switch decision {
        case .reject:
            status = .rejected
        case .accept, .edit:
            if case .edit(let change) = decision { proposal.change = change }
            let targetPath = try await resolveTarget(proposal, from: path)
            let current = targetPath.flatMap { try? String(contentsOf: vault.url(for: $0), encoding: .utf8) }
            switch try ProposalApplier.apply(proposal, to: current) {
            case .modify(let updated):
                guard let targetPath else { throw ProposalError.conflict("the target note no longer exists") }
                try await writer.write(updated, to: targetPath, as: .user)
                touched.append(targetPath)
            case .create(let newPath, let body):
                try await writer.write(body, to: newPath, as: .user)
                touched.append(newPath)
            }
            if case .edit = decision { status = .edited } else { status = .accepted }
        }

        var updated = try FrontmatterEditor.setScalar("status", to: status.rawValue, in: text)
        updated = try FrontmatterEditor.setScalar("decided", to: Self.day(now, calendar), in: updated)
        if case .edit(let change) = decision {
            if !updated.hasSuffix("\n") { updated += "\n" }
            updated += "\nEdited before accepting:\n\n```diff\n\(change.rendered)\n```\n"
        }
        try await writer.write(updated, to: path, as: .ai)
        try await appendLog(status: status, proposal: proposal, path: path, now: now)
        _ = try await indexer.update(paths: touched + [Self.logPath])
        let action: FeatureAction = switch status {
        case .accepted: .accepted
        case .edited: .edited
        default: .rejected
        }
        try state?.record(feature: proposal.feature, action: action, target: path, date: now)
    }

    // MARK: Helpers

    func resolveTarget(_ proposal: Proposal, from path: String) async throws -> String? {
        if proposal.createsNote {
            let exists = FileManager.default.fileExists(atPath: vault.url(for: proposal.target).path(percentEncoded: false))
            return exists ? proposal.target : nil
        }
        let target = Self.linkTarget(proposal.target)
        guard !target.isEmpty else { throw ProposalError.invalid("no target") }
        return try database.resolve(linkTarget: target, from: path)
    }

    /// "[[Notes/X#Heading|alias]]" → "Notes/X".
    static func linkTarget(_ raw: String) -> String {
        var target = raw.trimmingCharacters(in: .whitespaces)
        if target.hasPrefix("[["), target.hasSuffix("]]") { target = String(target.dropFirst(2).dropLast(2)) }
        if let bar = target.firstIndex(of: "|") { target = String(target[..<bar]) }
        if let hash = target.firstIndex(of: "#") { target = String(target[..<hash]) }
        return target.trimmingCharacters(in: .whitespaces)
    }

    public static func sameTarget(_ a: String, _ b: String) -> Bool {
        LinkRef.key(for: linkTarget(a)) == LinkRef.key(for: linkTarget(b))
    }

    func appendLog(status: ProposalStatus, proposal: Proposal, path: String, now: Date) async throws {
        let url = vault.url(for: Self.logPath)
        var log = (try? String(contentsOf: url, encoding: .utf8))
            ?? "# AI log\n\nEvery decision on an AI proposal, newest last.\n\n"
        if !log.hasSuffix("\n") { log += "\n" }
        let link = "[[\(String(path.dropLast(3)))|proposal]]"
        log += "- \(Self.stamp(now, calendar)) \(status.rawValue) \(proposal.kind.rawValue) \(proposal.target) "
            + "(\(proposal.feature), \(proposal.model)) \(link)\n"
        try await writer.write(log, to: Self.logPath, as: .ai)
    }

    public static func day(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func stamp(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return day(date, calendar) + String(format: " %02d%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
