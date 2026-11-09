# Spec: quick capture (KBCapture + app)

Status: **built** (phase 1, item 1). Plan refs: §2 principle 8, §7 feature 3, §4.3 (`Inbox/`).

## Inputs
- Text (required, non-empty after trimming), optional URL, optional title, optional "why I saved this".
- Entry points, all calling one `CaptureService`:
  - **Hotkey panel** (default ⌃⌥Space, changeable in Settings): type, ⌘↩ saves; the panel then asks "Why did you save this?" (↩ saves, Esc skips). Esc before saving discards.
  - **Menu bar** item: Capture…, Open granite.
  - **URL scheme**: `granite://capture?text=…&url=…&why=…&title=…` saves immediately; `granite://capture` with no text opens the panel; `granite://open?path=…` or `?id=…` opens a note.
  - **App Intent** "Capture to granite" (Shortcuts, Spotlight, Siri): text, link, why; runs in the background.

## Outputs
`Inbox/YYYY-MM-DD HHmm.md` (local time; `-2`, `-3` … on collision), written through `SafeWriter` as `.user`:

```markdown
---
id: 01JD…
type: note
kind: capture
origin: human
created: 2026-11-09T14:32:05+05:30
source: "https://…"        # only with a URL
why: "…"                   # only when given; added later via FrontmatterEditor
---
# Optional title

Captured text
```

## Rules
- Capture has zero required fields beyond the text and never waits on processing (principle 8). The "why" line is added afterwards with a one-line frontmatter edit.
- The vault is the one last opened in the app (remembered across launches). No vault → the panel and intent say "Open a vault in granite first".
- Inbox is `ai: local` in the built-in policy: captures never reach cloud models or MCP until moved.
- URL-scheme captures come from other apps and the web, so they write text only: no paths, no overwrites, length capped at 100k characters.

## Files
`Packages/KBCapture/` (`CaptureService`, `GraniteURL`), `App/Capture/` (panel, hotkey, menu bar, intent), `App/Info.plist` (URL type), `project.yml`.

## Done when
- [x] KBCapture tests (10): file naming and same-minute collisions under concurrency, frontmatter, why line, URL parsing and hostile-input rejection.
- [x] `open 'granite://capture?text=…'` writes an Inbox note (smoke-tested; LaunchServices ignores apps inside temp folders, so dev builds are copied to `build/`).
- [x] Panel becomes key 30 ms after the trigger on first show, 0.7 ms after (measured via `granite://capture`, which runs the same code as the hotkey).
- [ ] Hotkey pressed by hand (you): ⌃⌥Space from another app, type, ⌘↩, why, ↩.
- [x] App Intent metadata exported (`CaptureToGraniteIntent`: text, link, why) with an App Shortcut.
- [ ] Run it from Shortcuts or Spotlight (you).
