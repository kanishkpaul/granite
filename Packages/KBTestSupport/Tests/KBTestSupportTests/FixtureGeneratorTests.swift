import Foundation
import KBCore
import Testing
@testable import KBTestSupport

@Suite struct FixtureGeneratorTests {
    func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "granite-fixture-\(UUID().uuidString)")
    }

    @Test func generatesParseableDeterministicVault() throws {
        let first = tempDirectory()
        let second = tempDirectory()
        let summary = try FixtureGenerator(noteCount: 300, seed: 7, queryCount: 20).write(to: first)
        try FixtureGenerator(noteCount: 300, seed: 7, queryCount: 20).write(to: second)

        let files = Vault(root: first).markdownFiles()
        #expect(files.count == 300)
        #expect(summary.queries.count == 20)

        for file in files.prefix(50) {
            let a = try Data(contentsOf: first.appending(path: file.path))
            let b = try Data(contentsOf: second.appending(path: file.path))
            #expect(a == b)
            let note = NoteParser.parse(data: a, path: file.path, policy: .builtIn)
            #expect(note.id.flatMap(ULID.init) != nil)
            #expect(note.frontmatter?.error == nil)
            #expect(!note.blocks.isEmpty)
        }
        let allLinks = files.prefix(100).flatMap { file in
            NoteParser.parse(data: (try? Data(contentsOf: first.appending(path: file.path))) ?? Data(),
                             path: file.path, policy: .builtIn).links
        }
        #expect(!allLinks.isEmpty)
        #expect(!allLinks.contains { $0.target == "not a link" })
    }

    @Test func refusesNonEmptyOutput() throws {
        let directory = tempDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: directory.appending(path: "mine.md"))
        #expect(throws: FixtureError.self) { try FixtureGenerator(noteCount: 5).write(to: directory) }
    }
}
