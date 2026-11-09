import Foundation
import KBCore
import KBIndex
import Testing
@testable import KBCapture

func tempVault() throws -> Vault {
    let root = FileManager.default.temporaryDirectory.appending(path: "granite-capture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return Vault(root: root)
}

/// 2026-11-09 14:32:05 in Asia/Kolkata.
let fixedDate = Date(timeIntervalSince1970: 1_794_214_925)
let kolkata = TimeZone(identifier: "Asia/Kolkata") ?? .gmt

func service(_ vault: Vault) -> CaptureService {
    CaptureService(vault: vault, writer: SafeWriter(vault: vault), timeZone: kolkata, now: { fixedDate })
}

@Suite struct CaptureServiceTests {
    @Test func writesInboxNoteWithFrontmatter() async throws {
        let vault = try tempVault()
        let path = try await service(vault).capture(
            CaptureRequest(text: "  An idea about [[Hybrid retrieval]]  \n", url: URL(string: "https://example.com/a?b=1"),
                           title: "Idea", why: "for the retrieval essay"))
        #expect(path == "Inbox/2026-11-09 1432.md")
        let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        #expect(text.hasSuffix("---\n# Idea\n\nAn idea about [[Hybrid retrieval]]\n"))
        let note = NoteParser.parse(data: Data(text.utf8), path: path, policy: .builtIn)
        #expect(note.kind == "capture" && note.type == .note && note.origin == .human)
        #expect(note.aiLabel == .local, "Inbox captures stay local")
        #expect(note.id.flatMap(ULID.init) != nil)
        #expect(note.frontmatter?["created"]?.text == "2026-11-09T14:32:05+05:30")
        #expect(note.frontmatter?["source"]?.text == "https://example.com/a?b=1")
        #expect(note.frontmatter?["why"]?.text == "for the retrieval essay")
        #expect(note.links.map(\.target) == ["Hybrid retrieval"])
    }

    @Test func sameMinuteCapturesGetDistinctFiles() async throws {
        let vault = try tempVault()
        let capture = service(vault)
        let paths = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<5 { group.addTask { try await capture.capture(CaptureRequest(text: "note \(index)")) } }
            var all: [String] = []
            for try await path in group { all.append(path) }
            return all
        }
        #expect(Set(paths) == ["Inbox/2026-11-09 1432.md", "Inbox/2026-11-09 1432-2.md", "Inbox/2026-11-09 1432-3.md",
                               "Inbox/2026-11-09 1432-4.md", "Inbox/2026-11-09 1432-5.md"])
    }

    @Test func whyLineIsAddedAfterwards() async throws {
        let vault = try tempVault()
        let capture = service(vault)
        let path = try await capture.capture(CaptureRequest(text: "quick thought"))
        try await capture.setWhy("connects to\nthe claim ledger", for: path)
        let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        #expect(text.contains("why: connects to the claim ledger\n"))
        #expect(text.hasSuffix("---\nquick thought\n"))
        await #expect(throws: CaptureError.notACapture("Notes/x.md")) { try await capture.setWhy("x", for: "Notes/x.md") }
    }

    @Test func rejectsEmptyCaptures() async throws {
        let vault = try tempVault()
        await #expect(throws: CaptureError.emptyText) { try await service(vault).capture(CaptureRequest(text: " \n ")) }
    }

    @Test func yamlSpecialCharactersAreQuoted() async throws {
        let vault = try tempVault()
        let path = try await service(vault).capture(CaptureRequest(text: "x", why: "yes: really #1"))
        let note = NoteParser.parse(data: try Data(contentsOf: vault.url(for: path)), path: path, policy: .builtIn)
        #expect(note.frontmatter?.error == nil)
        #expect(note.frontmatter?["why"]?.text == "yes: really #1")
    }
}

@Suite struct GraniteURLTests {
    func parse(_ text: String) throws -> GraniteAction {
        try GraniteURL.parse(try #require(URL(string: text)))
    }

    @Test func captureWithText() throws {
        let action = try parse("granite://capture?text=Hello%20world&url=https%3A%2F%2Fexample.com&why=because&title=T")
        #expect(action == .capture(CaptureRequest(text: "Hello world", url: URL(string: "https://example.com"),
                                                  title: "T", why: "because")))
    }

    @Test func captureWithoutTextOpensPanel() throws {
        #expect(try parse("granite://capture") == .showCapturePanel)
        #expect(try parse("GRANITE://Capture?text=%20") == .showCapturePanel)
    }

    @Test func openByPathOrID() throws {
        #expect(try parse("granite://open?path=Notes/A%20b.md") == .open(path: "Notes/A b.md", id: nil))
        #expect(try parse("granite://open?id=01JC9Q7Z5W3K8M2R4T6V8X0Y1A") == .open(path: nil, id: "01JC9Q7Z5W3K8M2R4T6V8X0Y1A"))
        #expect(try parse("granite://pdf?path=Papers/pdf/doe2024dense.pdf&page=3&block=p3-ab12cd")
                == .pdf(path: "Papers/pdf/doe2024dense.pdf", page: 3, block: "p3-ab12cd"))
        #expect(try parse("granite://pdf?path=Papers/pdf/x.pdf&page=zero&block=%3Cscript%3E") == .pdf(path: "Papers/pdf/x.pdf", page: 1, block: nil))
        #expect(throws: GraniteURLError.self) { try parse("granite://pdf?path=../secret.pdf") }
        #expect(throws: GraniteURLError.self) { try parse("granite://pdf?path=Notes/a.md") }
        #expect(try parse("granite://clip?url=https%3A%2F%2Fexample.com%2Fa&why=later")
                == .clip(url: URL(string: "https://example.com/a")!, why: "later"))
        #expect(throws: GraniteURLError.self) { try parse("granite://clip?url=file%3A%2F%2F%2Fetc%2Fpasswd") }
    }

    @Test func rejectsHostileInput() throws {
        let bad = [
            "https://capture?text=x",
            "granite://delete?path=Notes/a.md",
            "granite://capture?text=x&url=javascript:alert(1)",
            "granite://capture?text=x&url=file:///etc/passwd",
            "granite://open?path=../outside.md",
            "granite://open?path=/etc/hosts",
            "granite://open?path=.git/config",
            "granite://open",
        ]
        for url in bad { #expect(throws: GraniteURLError.self, "\(url)") { try parse(url) } }
        let huge = String(repeating: "a", count: 100_001)
        #expect(throws: GraniteURLError.self) { try parse("granite://capture?text=\(huge)") }
    }

    @Test func capsWhyAndTitle() throws {
        let long = String(repeating: "w", count: 2_000)
        guard case .capture(let request) = try parse("granite://capture?text=x&why=\(long)&title=\(long)") else {
            Issue.record("expected capture")
            return
        }
        #expect(request.why?.count == 1_000 && request.title?.count == 300)
    }
}

@Suite struct NoteFactoryTests {
    func factory(_ vault: Vault) -> NoteFactory {
        NoteFactory(vault: vault, writer: SafeWriter(vault: vault), timeZone: kolkata, now: { fixedDate })
    }

    @Test func createsUniqueNotesWithFrontmatter() async throws {
        let vault = try tempVault()
        let notes = factory(vault)
        let first = try await notes.createNote(title: "Hybrid retrieval")
        let second = try await notes.createNote(title: "Hybrid retrieval")
        #expect(first == "Notes/Hybrid retrieval.md" && second == "Notes/Hybrid retrieval 2.md")
        let note = NoteParser.parse(data: try Data(contentsOf: vault.url(for: first)), path: first, policy: .builtIn)
        #expect(note.type == .note && note.origin == .human && note.id.flatMap(ULID.init) != nil)
        #expect(note.frontmatter?["created"]?.text == "2026-11-09T14:32:05+05:30")
        #expect(note.blocks.isEmpty)
    }

    @Test func concurrentCreatesNeverCollide() async throws {
        let vault = try tempVault()
        let notes = factory(vault)
        let paths = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<4 { group.addTask { try await notes.createNote(title: "Same") } }
            var all: [String] = []
            for try await path in group { all.append(path) }
            return all
        }
        #expect(Set(paths).count == 4)
    }

    @Test func sanitizesTitles() {
        #expect(NoteFactory.fileName(for: "a/b: c? [[x]] #tag ^id | y") == "a b c x tag id y")
        #expect(NoteFactory.fileName(for: "  ..hidden  ") == "hidden")
        #expect(NoteFactory.fileName(for: "///") == "Untitled")
        #expect(NoteFactory.fileName(for: String(repeating: "x", count: 300)).count == 120)
    }

    @Test func dailyNoteIsCreatedOnce() async throws {
        let vault = try tempVault()
        let notes = factory(vault)
        let first = try await notes.dailyNote()
        #expect(first.path == "Daily/2026-11-09.md" && first.created)
        try Data("---\ntype: daily\n---\nmy day\n".utf8).write(to: vault.url(for: first.path))
        let again = try await notes.dailyNote()
        #expect(again.path == first.path && !again.created)
        #expect(try String(contentsOf: vault.url(for: first.path), encoding: .utf8).hasSuffix("my day\n"))
        let note = NoteParser.parse(data: try Data(contentsOf: vault.url(for: "Daily/2026-11-09.md")), path: "Daily/2026-11-09.md",
                                    policy: .builtIn)
        #expect(note.type == .daily)
    }
}

@Suite struct InboxQueueTests {
    /// Vault with captures aged 3, 20 and 90 days relative to `fixedDate`.
    func setup() async throws -> (Vault, InboxQueue, IndexDatabase) {
        let vault = try tempVault()
        let writer = SafeWriter(vault: vault)
        func put(_ path: String, _ text: String) throws {
            let url = vault.url(for: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        try put("Inbox/2026-11-06 1000.md", "---\nkind: capture\n---\nfresh thought\n")
        try put("Inbox/2026-10-20 0900.md", "---\nkind: capture\ncreated: 2026-10-20T09:00:00+05:30\nwhy: for the essay\n---\nolder thought about [[Target]]\n")
        try put("Inbox/ancient.md", "---\ncreated: 2026-08-01\n---\nvery old\n")
        try put("Notes/Target.md", "# Target\nexisting text\n")
        try put("Notes/Ref.md", "links to [[2026-10-20 0900]]\n")
        let database = try IndexDatabase(url: vault.root.deletingLastPathComponent().appending(path: "idx-\(UUID().uuidString)/index.sqlite"))
        let indexer = Indexer(database: database, vault: vault, policy: .builtIn)
        _ = try await indexer.reconcile()
        let queue = InboxQueue(indexer: indexer, writer: writer, renamer: RenameService(indexer: indexer, writer: writer),
                               timeZone: kolkata, now: { fixedDate })
        return (vault, queue, database)
    }

    @Test func agesAndQueue() async throws {
        let (_, queue, _) = try await setup()
        let items = await queue.items()
        #expect(items.map(\.title) == ["ancient", "2026-10-20 0900", "2026-11-06 1000"])
        #expect(items.map(\.ageDays) == [100, 20, 3])
        #expect(items[1].why == "for the essay")
        #expect(items[1].preview == "older thought about [[Target]]")
        #expect(await queue.decideQueue().map(\.title) == ["ancient", "2026-10-20 0900"])
        #expect(await queue.medianAgeDays() == 20)
    }

    @Test func makeNoteRewritesLinksAndChangesKind() async throws {
        let (vault, queue, database) = try await setup()
        let path = try await queue.makeNote("Inbox/2026-10-20 0900.md", title: "Older thought")
        #expect(path == "Notes/Older thought.md")
        let text = try String(contentsOf: vault.url(for: path), encoding: .utf8)
        #expect(text.contains("kind: evergreen"))
        #expect(try String(contentsOf: vault.url(for: "Notes/Ref.md"), encoding: .utf8) == "links to [[Older thought]]\n")
        #expect(try database.backlinks(to: path).map(\.path) == ["Notes/Ref.md"])
    }

    @Test func appendThenArchive() async throws {
        let (vault, queue, _) = try await setup()
        try await queue.append("Inbox/2026-10-20 0900.md", to: "Notes/Target.md")
        let target = try String(contentsOf: vault.url(for: "Notes/Target.md"), encoding: .utf8)
        #expect(target == "# Target\nexisting text\n\n## From inbox, 2026-10-20\n\nolder thought about [[Target]]\n")
        #expect(FileManager.default.fileExists(atPath: vault.url(for: "Archive/Inbox/2026-10-20 0900.md").path(percentEncoded: false)))
        #expect(await queue.items().count == 2)
    }

    @Test func bankruptcyArchivesOnlyOldItems() async throws {
        let (vault, queue, database) = try await setup()
        let archived = try await queue.bankruptcy()
        #expect(archived == ["Archive/Inbox/ancient.md"])
        #expect(await queue.items().map(\.title) == ["2026-10-20 0900", "2026-11-06 1000"])
        #expect(try database.note(path: "Archive/Inbox/ancient.md") != nil)
        try Data("dup".utf8).write(to: vault.url(for: "Inbox/ancient.md"))
        #expect(try await queue.archive("Inbox/ancient.md") == "Archive/Inbox/ancient 2.md")
    }
}
