# 0003: Spike A (CodeMirror 6 in WKWebView) passes its automated gates

Date: 2026-11-09 · Status: **accepted, pending manual checks** · Plan: §8 spike A, §12 research gap 1

## Context
The plan bets on CodeMirror 6 in a `WKWebView` over TextKit 2 for long Markdown files, with STTextView behind an `EditorView` protocol as the fallback. No published benchmark compared them, so the spike measures CM6 in the real host.

## What was built
`Editor/` (TypeScript, CM 6.43 view / 6.7 state, lang-markdown 6.5, Vite 8 IIFE bundle, Vitest 5), a typed bridge mirrored in `App/Bridges/EditorBridge.swift`, an `EditorController` hosting the bundle from `file://`, live-preview decorations, and an in-app benchmark (`--editor-bench`) that runs inside the real `WKWebView`.

## Method
A 50,008-line, 7.4 MB note made from fixture notes (9,039 wikilinks, headings, callouts, code blocks, lists). Release build on Apple M5, 16 GB, macOS 27.0.1, 1000×800 window. Keystroke cost = synchronous dispatch + CodeMirror's work in the next frame (the gap between an animation-frame callback registered before the keystroke and one registered after it). WebKit coarsens `performance.now()` to 1 ms. Five runs; the numbers below are the last two, which agree with the earlier three.

## Results

| Gate | Target | Measured | Pass |
|---|---|---|---|
| Open 50k-line file (host send → laid out and painted) | < 1 s | 71–83 ms cold, 43–44 ms warm | yes |
| Keystroke-to-paint p95, parsed document | < 16 ms | 7–12 ms overall (start 2, middle 5, end 7–13) | yes |
| Same, typed through the contenteditable (real input path) | < 16 ms | 8–13 ms | yes |
| Keystroke p95 right after jumping deep into an unparsed region | — | 22–24 ms | **no** (transient) |
| Smooth scroll, top to bottom in 3 s | no hitches | 17 ms median frame (60 Hz), 2–5 of ~180 frames over 20 ms | yes |
| Undo and redo across the bridge | exact | document restored and re-applied exactly | yes |
| CJK IME composition | composes correctly | not measured | **manual** |
| Drag and drop, VoiceOver, focus | work | not measured | **manual** |

## Findings
1. **The slow keystrokes are the parser catching up.** On each transaction CodeMirror parses for up to ~20 ms to bring the syntax tree to the viewport. After a jump to line 25,000 or 50,000 of a 7.4 MB file, every keystroke pays that budget until the tree arrives. Once parsed, the same positions type in 5–13 ms. In normal use the background parser catches up while you read; if it matters, prime it with `forceParsing` to the cursor on deep jumps.
2. **The bundle loads as a classic script.** ES modules over `file://` can be blocked in WKWebView; the Vite build emits an IIFE plus `editor.html`.
3. **Benchmarks need a visible window.** WebKit pauses animation frames for occluded windows; one run hung until the bench brought its window forward and gained a 3-minute timeout.
4. **Bundle size is 546 KB minified** (189 KB gzip), mostly lang-markdown's embedded HTML/CSS/JS grammars. It loads from disk, so this is cosmetic; trim `codeLanguages` later if startup matters.

## Decision
Keep CodeMirror 6 in WKWebView as the editor. Do not build the STTextView fallback unless the manual IME, accessibility or drag-and-drop checks fail.

## Manual checks still needed (you, at the keyboard)
Open a vault in the app (use `~/VaultCopy`, not `~/Vault`: the spike editor saves on every pause), open a note, then:
1. Type Japanese or Chinese with the system IME: composition underline, candidate window position, commit, backspace mid-composition.
2. ⌘Z / ⇧⌘Z after typing, and after an IME commit.
3. Drag text within the note, and drag a file from Finder onto the editor.
4. VoiceOver (⌘F5): reading lines, moving by word.
5. ⌘-click a `[[link]]` to open it.
