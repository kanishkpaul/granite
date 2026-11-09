# Spec: Phase 1, daily driver (frozen 2026-11-09)

Plan refs: §8 phase 1, §7 feature 3, §10, §13 day 10. Phase 0 outcomes: decisions 0001–0007.

## Goal
You write in granite instead of Obsidian for 7 consecutive days.

## Already built in phase 0
CM6 editor with live preview and typed bridge · FTS5 search (p95 1.8 ms on 50k notes) · backlinks and link resolution · FSEvents watcher with replay · read-only `granite-mcp` · `granite-cli` · local hybrid search (not yet in the app).

## Phase 1 scope, in build order
| # | Piece | Spec | Done when |
|---|---|---|---|
| 1 ✓ | Quick capture: hotkey panel, menu bar, `granite://` URLs, App Intent, Inbox with a "why" line | `capture.md` | You capture something real through the hotkey; the panel appears in < 300 ms |
| 2 ✓ | Git auto-commit + deletion alarm (`GitService`) | `git.md` | Commits 5 min after the last change and on quit; > 20 staged deletions or any 0-byte `.md` pauses commits and alerts |
| 3 | App shell: sidebar (folders), note list, backlinks pane, quick switcher (⌘O), command palette (⌘K), daily notes (⌘D), properties panel | `app-shell.md` (to write) | Every daily action works without Finder or Obsidian |
| 4 | Editor: `[[`/`#` completion, inline embeds, external-change banner | `editor.md` | Linking a note never needs the mouse |
| 5 | Inbox decide queue: items > 14 days ask make-note / link / archive; bankruptcy moves > 60 days to `Archive/` | `capture.md` | Inbox median age < 14 days |

## Phase 1 gates (plan §8)
- [ ] 7 consecutive days in granite.
- [x] Capture panel < 300 ms (30 ms first show, 0.7 ms after).
- [x] FTS p95 < 50 ms on the 50k fixture (1.8 ms, decision 0001).
- [ ] Claude Code answers a question through `granite-mcp` citing a note path (decision 0004; needs the CLI signed in).

## Out of scope for phase 1
Hybrid search in the app, proposals, Zotero (deferred, 0005), FSRS, digests, Claude/PCC routes.

## Prerequisites (you)
- `~/Vault` under git with a pushed private remote before granite writes to it daily (plan §10). granite can now initialize git (Settings) and commits and pushes automatically; add the private remote yourself.
- 20 re-find queries in `.granite/eval/retrieval.jsonl`.
