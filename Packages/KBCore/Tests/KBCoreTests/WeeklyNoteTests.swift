import Foundation
import Testing
@testable import KBCore

@Suite struct WeeklyNoteTests {
    @Test func isoWeeks() {
        let utc = TimeZone(identifier: "UTC") ?? .gmt
        #expect(WeeklyNote.week(of: Date(timeIntervalSince1970: 1_794_214_925), timeZone: utc) == "2026-W46")  // Mon 9 Nov 2026
        #expect(WeeklyNote.week(of: Date(timeIntervalSince1970: 1_767_139_200), timeZone: utc) == "2026-W01")  // Thu 31 Dec 2025
        #expect(WeeklyNote.path(for: "2026-W46") == "Daily/2026-W46.md")
    }

    @Test func rendersAndAppendsUnderQuestions() {
        let first = WeeklyNote.render(week: "2026-W46", answers: [("What changed your mind this week?", "Reranking matters."),
                                                                   ("Which claim would you defend least, and why?", "  ")],
                                      date: "2026-11-09")
        let note = NoteParser.parse(data: Data(first.utf8), path: "Daily/2026-W46.md", policy: .builtIn)
        #expect(note.type == .daily && note.origin == .human && note.kind == "weekly")
        #expect(first.hasSuffix("# Week 2026-W46\n\n## What changed your mind this week?\nReranking matters.\n"))
        #expect(!first.contains("defend least"))

        let second = WeeklyNote.render(week: "2026-W46", answers: [("What changed your mind this week?", "Also BM25."),
                                                                    ("What will you think about next week?", "Trails.")],
                                       existing: first + "\nMy own extra line.\n", date: "2026-11-09")
        #expect(second.contains("## What changed your mind this week?\nReranking matters.\n\nMy own extra line.\n\nAlso BM25.\n"))
        #expect(second.hasSuffix("## What will you think about next week?\nTrails.\n"))
    }
}
