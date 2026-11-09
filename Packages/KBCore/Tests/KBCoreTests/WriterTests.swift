import CryptoKit
import Foundation
import Testing
@testable import KBCore

@Suite struct ULIDTests {
    @Test func roundTripsTimestamp() throws {
        let date = Date(timeIntervalSince1970: 1_762_560_000.123)
        let ulid = ULID(date: date)
        #expect(ulid.string.count == 26)
        #expect(ulid.timestampMillis == 1_762_560_000_123)
        let parsed = try #require(ULID(ulid.string.lowercased()))
        #expect(parsed == ulid)
    }

    @Test func sortsByTime() {
        let early = ULID(date: Date(timeIntervalSince1970: 1_000))
        let late = ULID(date: Date(timeIntervalSince1970: 2_000))
        #expect(early < late)
    }

    @Test func rejectsInvalid() {
        #expect(ULID("not-a-ulid") == nil)
        #expect(ULID("8ZZZZZZZZZZZZZZZZZZZZZZZZZ") == nil)
        #expect(ULID("01JC9Q7Z5W3K8M2R4T6V8X0Y1U") == nil) // U is not Crockford
    }
}

@Suite struct FrontmatterEditorTests {
    static let goldenNames = ["claim", "crlf", "bom", "no-frontmatter", "unclosed-frontmatter", "bad-yaml",
                              "code-blocks", "callouts", "block-ids", "tags", "links", "comments"]

    /// Stamping an id changes exactly one line and leaves every other byte alone.
    @Test(arguments: goldenNames)
    func stampingIDIsMinimal(name: String) throws {
        let original = String(decoding: try golden(name), as: UTF8.self)
        if name == "bad-yaml" {
            #expect(throws: FrontmatterEditor.InvalidYAML.self) {
                try FrontmatterEditor.setScalar("id", to: "x", in: original)
            }
            return
        }
        let stamped = try FrontmatterEditor.setScalar("id", to: "01JC9Q7Z5W3K8M2R4T6V8X0Y1B", in: original)
        let reparsed = NoteParser.parse(data: Data(stamped.utf8), path: "Notes/x.md", policy: .builtIn)
        #expect(reparsed.id == "01JC9Q7Z5W3K8M2R4T6V8X0Y1B")
        #expect(stamped.hasPrefix("\u{FEFF}") == original.hasPrefix("\u{FEFF}"))

        let before = Lines.split(original)
        let after = Lines.split(stamped)
        let changed = after.count - before.count
        #expect([0, 1, 3].contains(changed))
        // Removing the stamped lines must give back the original bytes.
        let originalText = original.hasPrefix("\u{FEFF}") ? String(original.dropFirst()) : original
        let restored = after.filter { line in
            !(line.text.hasPrefix("id: 01JC9Q7Z5W3K8M2R4T6V8X0Y1B"))
                && !(changed == 3 && line.index == 2 && line.text == "---")
                && !(changed == 3 && line.index == 0 && line.text == "---")
        }
        if changed > 0 {
            let reassembled = restored.map { $0.text + $0.terminator }.joined()
            let strippedAfter = reassembled.hasPrefix("\u{FEFF}") ? String(reassembled.dropFirst()) : reassembled
            #expect(strippedAfter == originalText)
        }
    }

    @Test func replacesExistingScalar() throws {
        let text = "---\nid: old\ntitle: x\n---\nbody\n"
        #expect(try FrontmatterEditor.setScalar("id", to: "new", in: text) == "---\nid: new\ntitle: x\n---\nbody\n")
    }

    @Test func keepsCRLF() throws {
        let text = "---\r\ntitle: x\r\n---\r\nbody\r\n"
        #expect(try FrontmatterEditor.setScalar("id", to: "a", in: text) == "---\r\nid: a\r\ntitle: x\r\n---\r\nbody\r\n")
    }

    @Test func quotesAmbiguousScalars() {
        #expect(FrontmatterEditor.yamlScalar("yes") == "\"yes\"")
        #expect(FrontmatterEditor.yamlScalar("1.5") == "\"1.5\"")
        #expect(FrontmatterEditor.yamlScalar("a: b") == "\"a: b\"")
        #expect(FrontmatterEditor.yamlScalar("[[Link]]") == "\"[[Link]]\"")
        #expect(FrontmatterEditor.yamlScalar("plain words") == "plain words")
    }
}

@Suite struct SafeWriterTests {
    func tempVault() throws -> Vault {
        let root = FileManager.default.temporaryDirectory.appending(path: "granite-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Vault(root: root)
    }

    @Test func aiCanOnlyWriteUnderAI() async throws {
        let vault = try tempVault()
        let writer = SafeWriter(vault: vault)
        try await writer.write("ok", to: "AI/Digests/2026-11-09.md", as: .ai)
        await #expect(throws: SafeWriteError.aiWriteOutsideAI("Notes/x.md")) {
            try await writer.write("no", to: "Notes/x.md", as: .ai)
        }
        await #expect(throws: SafeWriteError.aiWriteOutsideAI("AI")) {
            try await writer.write("no", to: "AI", as: .ai)
        }
        #expect(!FileManager.default.fileExists(atPath: vault.url(for: "Notes/x.md").path(percentEncoded: false)))
    }

    @Test func refusesEscapesAndObsidianConfig() async throws {
        let writer = SafeWriter(vault: try tempVault())
        await #expect(throws: SafeWriteError.outsideVault("../escape.md")) {
            try await writer.write("x", to: "../escape.md", as: .user)
        }
        await #expect(throws: SafeWriteError.outsideVault("/etc/x.md")) {
            try await writer.write("x", to: "/etc/x.md", as: .user)
        }
        await #expect(throws: SafeWriteError.forbiddenPath(".obsidian/app.json")) {
            try await writer.write("x", to: ".obsidian/app.json", as: .user)
        }
    }

    @Test func echoesAreRecognizedOnce() async throws {
        let vault = try tempVault()
        let writer = SafeWriter(vault: vault)
        try await writer.write("hello", to: "Inbox/a.md", as: .user)
        let hash = Data(SHA256.hash(data: Data("hello".utf8)))
        #expect(await writer.isEcho(path: "Inbox/a.md", hash: hash))
        #expect(await !writer.isEcho(path: "Inbox/a.md", hash: hash))
        let written = try String(contentsOf: vault.url(for: "Inbox/a.md"), encoding: .utf8)
        #expect(written == "hello")
    }

    @Test func scansMarkdownSkippingHiddenFolders() throws {
        let vault = try tempVault()
        for path in ["Notes/a.md", "Notes/deep/b.md", ".obsidian/c.md", ".git/d.md", "Notes/e.txt", "root.md"] {
            let url = vault.url(for: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: url)
        }
        let paths = Set(vault.markdownFiles().map(\.path))
        #expect(paths == ["Notes/a.md", "Notes/deep/b.md", "root.md"])
    }
}
