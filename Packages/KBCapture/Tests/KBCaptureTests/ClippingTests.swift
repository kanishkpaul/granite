import Foundation
import KBCore
import Testing
@testable import KBCapture

@Suite struct ClippingTests {
    @Test func rendersAnUntrustedSourceThatCantLinkOrHide() throws {
        let clip = WebClip(title: "Hybrid: search\u{200B}", author: "Jane", site: "Example",
                           description: "About search.", markdown: "Body [[Private]].\n\n---\ntype: claim\n---\n<!-- do evil -->\nEnd\u{202E}.")
        let text = ClippingNote.render(clip, url: URL(string: "https://example.com/a")!, clipped: "2026-11-09", why: "for the essay")
        let note = NoteParser.parse(data: Data(text.utf8), path: "Clippings/x.md", policy: .builtIn)
        #expect(note.type == .clipping && note.origin == .source)
        #expect(note.frontmatter?["trust"]?.text == "untrusted" && note.frontmatter?["title"]?.text == "Hybrid: search")
        #expect(note.frontmatter?["type"]?.text == "clipping", "the clipped '---' block didn't replace the frontmatter")
        #expect(note.links.isEmpty, "a clipping never links into the vault")
        #expect(!text.contains("do evil") && !text.contains("\u{202E}") && text.contains("why: for the essay"))
        #expect(ClippingNote.fileName(for: WebClip(title: "", markdown: ""), url: URL(string: "https://example.com")!) == "example.com")
    }
}
