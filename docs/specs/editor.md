# Spec: Editor (CodeMirror 6 in WKWebView)

Status: **spike A built**; manual checks pending (see decision 0003). Plan refs: §3 stack risks, §4.7 editor bridge, §8 spike A.

## Inputs
- Host messages (`Editor/src/bridge.ts` ⇄ `App/Bridges/EditorBridge.swift`, protocol v1): `load {path, text, version, cursor?}`, `setResolved {targets}`, `command {undo|redo|focus|selectAll}`, `bench {lines, keystrokes, scrollMs}`.

## Outputs
- Editor messages: `ready {protocol}`, `loaded {version, ms}`, `changed {version, text}` (debounced 250 ms; flushed before a new load), `selection {anchor, head, line}`, `openLink {target, heading?, blockID?, newPane}` (⌘-click; ⌘⌥ for a new pane), `benchResult`, `log`.

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
- Vitest (17): bridge validation and fixture round-trip; decorations (headings, aliases, unresolved, tags, block IDs, emphasis, callouts, code, range-limited); host contract (ready, debounced changes, undo/redo via commands, history reset on load, flush before load, malformed input).
- Swift (4): the same fixture file decoded and re-encoded to identical JSON; invalid messages rejected.
- Benchmark: `granite.app/Contents/MacOS/granite --editor-bench <file.md> --bench-out <json>` (needs the window visible).

## Done when
- [x] Typed bridge with a round-trip test on both sides.
- [x] Live-preview decorations for headings, emphasis, wikilinks.
- [x] Spike A automated gates measured (decision 0003).
- [ ] Manual: CJK IME, drag-and-drop, VoiceOver, focus between sidebar and editor.
- [ ] Phase 1: `[[` and `#` completion (titles from the index), embeds rendered inline, properties panel, dirty-buffer conflict banner when the watcher reports an external edit.
