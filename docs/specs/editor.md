# Spec: Editor (CodeMirror 6 in WKWebView)

Status: **phase 1 item 4 built** (protocol v2); spike A manual checks pending (decision 0003). Plan refs: §3 stack risks, §4.7 editor bridge, §8 spike A.

## Inputs
- Host messages (`Editor/src/bridge.ts` ⇄ `App/Bridges/EditorBridge.swift`, protocol v2): `load {path, text, version, cursor?}`, `setResolved {targets}`, `command {undo|redo|focus|selectAll}`, `bench {…}`, `completions {id, items}`, `embed {id, target, kind, title?, text?, dataURL?}`, `external {path, text}`.

## Outputs
- Editor messages: `ready {protocol}`, `loaded {version, ms}`, `changed {version, text}` (debounced 250 ms; flushed before a new load), `selection {anchor, head, line}`, `openLink {target, heading?, blockID?, newPane}` (⌘-click; ⌘⌥ for a new pane), `benchResult`, `log`, `complete {id, kind: link|tag, query}`, `resolveEmbed {id, target}`. Requests the host doesn't answer within 1.5 s resolve to an empty result.

## Behaviour
- Swift owns all file I/O. The editor never touches disk.
- `load` replaces the state: undo history never crosses notes. A load is not reported as a change.
- Versions: the host sets one per load; each local edit increments it; the host ignores `changed` with a version it has already seen.
- Malformed host messages are rejected with a `log` message, never thrown into the page.
- Live preview (Obsidian-style): heading, emphasis, strikethrough and inline-code marks are hidden except on lines the selection touches; wikilinks and embeds show their alias (or target) off the active line; unresolved links are dimmed once the host sends `setResolved`; tags, `^block-ids`, callouts and code blocks are styled. Only visible ranges are decorated.
- Obsidian syntax is parsed into the Lezer tree (`WikiLink`, `Embed`, `Tag`, `BlockID`), matching KBCore's rules (link keys, anchors, tag characters).
- In the app: search hit → `load` at the hit's line; edits → `SafeWriter` (role `.user`) → `Indexer.update` for that path → fresh `setResolved`; ⌘-click a link → `IndexDatabase.resolve(linkTarget:from:)` → `load`.

## Files
`Editor/src/{bridge,editor,livePreview,wikilink,theme,main}.ts`, `Editor/public/editor.html`, `Editor/test/*`, built output `App/Resources/editor/` (committed so the app builds without pnpm), `App/Bridges/{EditorBridge,EditorController}.swift`, `App/EditorBench.swift`, `Tests/AppTests/EditorBridgeTests.swift`.

## Tests
- Vitest (29): v2 adds frontmatter fold, completion triggers and provider mapping, request timeouts, minimal diff, external-change flow (quiet apply, Keep mine, Take theirs), embed caching, callouts and quotes. Phase 0 set: bridge validation and fixture round-trip; decorations (headings, aliases, unresolved, tags, block IDs, emphasis, callouts, code, range-limited); host contract (ready, debounced changes, undo/redo via commands, history reset on load, flush before load, malformed input).
- Swift (4): the same fixture file (14 host, 11 editor messages) decoded and re-encoded to identical JSON; invalid messages rejected.
- Benchmark: `granite.app/Contents/MacOS/granite --editor-bench <file.md> --bench-out <json>` (needs the window visible).

## Done when
- [x] Typed bridge with a round-trip test on both sides.
- [x] Live-preview decorations for headings, emphasis, wikilinks.
- [x] Spike A automated gates measured (decision 0003).
- [ ] Manual: CJK IME, drag-and-drop, VoiceOver, focus between sidebar and editor.
- [x] Phase 1 item 4: `[[` completion (titles and aliases from the index; recent notes on an empty query; the closing `]]` is skipped over) and `#` completion (tags by use count).
- [x] Frontmatter folds into a one-line properties summary until the cursor enters it; notes open with the cursor in the body.
- [x] Callouts show an icon and type label instead of `> [!type]`; quote markers hide off the active line.
- [x] Embeds render inline: note sections (`#Heading`) and blocks (`#^id`) as text, images (vault path, next to the note, `Attachments/`, then by name) as data URLs up to 8 MB; missing targets say so. Paths with `..` are refused.
- [x] A note changed on disk applies as a minimal edit (cursor and undo kept, never echoed back); with unsent local edits the editor shows Keep mine / Take theirs.
- [ ] Typed by hand in the app (you): `[[` and `#` completion, the banner.
