# Spec: app shell (phase 1, item 3)

Status: **built**. Plan refs: §4.2, §8 phase 1 ("sidebar, note list, … quick switcher, ⌘K palette; backlinks; daily notes; properties panel"), anti-features in §2.

## Layout
Three columns plus an inspector:

| Sidebar | Note list | Editor | Inspector (⌥⌘I) |
|---|---|---|---|
| Inbox (with count), Today, then vault folders with note counts, by type not topic (plan §4.3) | Notes in the selected folder, newest first; replaced by search results while the search field has text | CodeMirror note | Backlinks (with relation: links, embed, supports, supersedes, …), then properties: type, origin, AI label, created, tags, frontmatter |

The inspector holds links and facts about the open note, not AI suggestions (plan §2: related items must be inline, never hidden in an inspector).

## Commands
| Shortcut | Command |
|---|---|
| ⌘O | Quick switcher: title and alias match; empty field shows recent notes; ↩ opens; ⌘↩ (or the last row) creates `Notes/<typed title>.md` |
| ⌘K | Command palette: every command below plus note titles |
| ⌘N | New note in `Notes/` (title prompt via the switcher) |
| ⌘D | Today's daily note `Daily/YYYY-MM-DD.md`, created if missing |
| ⌘F | Focus search |
| ⌥⌘I | Toggle inspector |
| ⌃⌥Space | Capture (global) |
| — | Open vault…, reveal in Finder, copy wikilink, commit now |

## Rules
- New notes and daily notes are created through `KBCapture.NoteFactory` → `SafeWriter` (role `.user`) with `id`, `type`, `origin: human`, `created`. Existing files are never overwritten; a taken title gets ` 2`, ` 3` ….
- Lists come from SQL (paged), never from holding every note in memory (plan §4.2).
- Selecting a note in any list opens it in the editor; the inspector follows the open note.

## Files
`Packages/KBIndex/Sources/KBIndex/Browse.swift` (folders, notes in folder, recent), `Packages/KBCapture/Sources/KBCapture/NoteFactory.swift`, `App/Shell/` (views, switcher, palette, commands).

## Known gaps
- New-note titles are prompted through the switcher; renaming notes (with link rewriting) is not built.

## Done when
- [x] Tests for folder counts, folder listing order, note creation (unique names, frontmatter) and daily notes.
- [x] App builds; `granite --snapshot out.png --open <path>` shows list, editor and inspector, and logs the sidebar's folders (the capture can't draw the sidebar's translucent material).
- [x] Fixed on the way: lists load from an existing index at launch (the watcher only replays changes, so no update may arrive); quitting no longer waits when nothing needs committing.
- [ ] You can do every daily action without Finder or Obsidian (your call, during the 7-day trial).
