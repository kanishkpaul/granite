import Foundation
import KBCore
import KBIndex

public struct InboxItem: Sendable, Hashable, Identifiable {
    public let path: String
    public let title: String
    public let created: Date
    public let why: String?
    /// First line of the body, for the list.
    public let preview: String
    public let ageDays: Int

    public var id: String { path }
}

/// The Inbox as a decide queue (master plan §7 feature 3): items older than 14 days ask for a
/// decision, and bankruptcy archives everything older than 60 days. Processing never blocks capture.
public actor InboxQueue {
    public static let decideAfterDays = 14
    public static let bankruptAfterDays = 60
    public static let archiveFolder = "Archive/Inbox"

    let vault: Vault
    let writer: SafeWriter
    let renamer: RenameService
    let indexer: Indexer
    let timeZone: TimeZone
    let now: @Sendable () -> Date

    public init(indexer: Indexer, writer: SafeWriter, renamer: RenameService, timeZone: TimeZone = .current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.vault = indexer.vault
        self.indexer = indexer
        self.writer = writer
        self.renamer = renamer
        self.timeZone = timeZone
        self.now = now
    }

    /// Every Inbox item, oldest first.
    public func items() -> [InboxItem] {
        let today = now()
        return vault.markdownFiles(under: CaptureService.folder).compactMap { file -> InboxItem? in
            guard let data = try? Data(contentsOf: vault.url(for: file.path)) else { return nil }
            let note = NoteParser.parse(data: data, path: file.path, policy: .builtIn)
            let created = Self.createdDate(note: note, fileName: note.title, mtime: file.mtime, timeZone: timeZone)
            let age = max(0, Int(today.timeIntervalSince(created) / 86_400))
            let preview = note.blocks.first { $0.kind != .heading }?.text.split(separator: "\n").first.map(String.init)
                ?? note.blocks.first?.text ?? ""
            return InboxItem(path: file.path, title: note.title, created: created,
                             why: note.frontmatter?["why"]?.text, preview: String(preview.prefix(200)), ageDays: age)
        }
        .sorted { $0.created < $1.created }
    }

    /// Items old enough to need a decision.
    public func decideQueue() -> [InboxItem] {
        items().filter { $0.ageDays > Self.decideAfterDays }
    }

    public func medianAgeDays() -> Double? {
        let ages = items().map(\.ageDays).sorted()
        guard !ages.isEmpty else { return nil }
        let middle = ages.count / 2
        return ages.count.isMultiple(of: 2) ? Double(ages[middle - 1] + ages[middle]) / 2 : Double(ages[middle])
    }

    /// Make note: becomes `Notes/<title>.md` (links rewritten) with `kind: evergreen`.
    public func makeNote(_ path: String, title: String, folder: String = NoteFactory.notesFolder) async throws -> String {
        let stem = NoteFactory.fileName(for: title)
        let destination = uniquePath(folder: folder, stem: stem)
        _ = try await renamer.rename(from: path, to: destination)
        if let text = try? String(contentsOf: vault.url(for: destination), encoding: .utf8),
           let updated = try? FrontmatterEditor.setScalar("kind", to: "evergreen", in: text) {
            try await writer.write(updated, to: destination, as: .user)
            _ = try await indexer.update(paths: [destination])
        }
        return destination
    }

    /// Append to note: the capture's body goes under "## From inbox, <date>" in `note`; the capture is archived.
    public func append(_ path: String, to note: String) async throws {
        let captureData = try Data(contentsOf: vault.url(for: path))
        let capture = MarkdownDocument(text: String(decoding: captureData, as: UTF8.self))
        let body = capture.bodyLines.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var target = try String(contentsOf: vault.url(for: note), encoding: .utf8)
        let created = items().first { $0.path == path }?.created ?? now()
        if !target.hasSuffix("\n") { target += "\n" }
        target += "\n## From inbox, \(NoteFactory.dayString(created, timeZone: timeZone))\n\n\(body)\n"
        try await writer.write(target, to: note, as: .user)
        let archived = try await archive(path)
        _ = try await indexer.update(paths: [note, path, archived])
    }

    /// Archive: moves to `Archive/Inbox/` (never overwriting).
    @discardableResult
    public func archive(_ path: String) async throws -> String {
        let name = NoteParser.title(for: path)
        let destination = uniquePath(folder: Self.archiveFolder, stem: name)
        try await writer.move(from: path, to: destination, as: .user)
        _ = try await indexer.update(paths: [path, destination])
        return destination
    }

    /// Bankruptcy: archives every item older than 60 days. Returns the new paths.
    public func bankruptcy() async throws -> [String] {
        var archived: [String] = []
        for item in items() where item.ageDays > Self.bankruptAfterDays {
            archived.append(try await archive(item.path))
        }
        return archived
    }

    func uniquePath(folder: String, stem: String) -> String {
        var candidate = "\(folder)/\(stem).md"
        var counter = 2
        while FileManager.default.fileExists(atPath: vault.url(for: candidate).path(percentEncoded: false)) {
            candidate = "\(folder)/\(stem) \(counter).md"
            counter += 1
        }
        return candidate
    }

    /// `created` from frontmatter, else a "YYYY-MM-DD HHmm" file name, else the modification time.
    static func createdDate(note: ParsedNote, fileName: String, mtime: Double, timeZone: TimeZone) -> Date {
        if let raw = note.created {
            let full = ISO8601DateFormatter()
            if let date = full.date(from: raw) { return date }
            let day = ISO8601DateFormatter()
            day.formatOptions = [.withFullDate]
            day.timeZone = timeZone
            if let date = day.date(from: String(raw.prefix(10))) { return date }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        if let date = formatter.date(from: String(fileName.prefix(15))) { return date }
        return Date(timeIntervalSinceReferenceDate: mtime)
    }
}
