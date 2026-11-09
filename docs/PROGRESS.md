# Build progress, phases 1–4

The plan says not to start a phase until the previous phase's "done when" holds (§12, "overbuilding before value"). Those gates measure your use of granite (7 days in it, a Q&A a day, weekly reviews). On 2026-11-09 you asked for phases 1–4 to be built end to end first; the gates stay in place as the yardstick once you start using it. Items marked **you** need your hands, account or judgement.

Legend: ✓ built and tested · ◐ built, needs something from you · — deferred with a decision record.

## Phase 1: daily driver
| Item | Status | Where |
|---|---|---|
| Quick capture (hotkey, menu bar, URLs, App Intent) | ✓ | `KBCapture`, `App/Capture`, spec `capture.md` |
| Git auto-commit + deletion alarm | ✓ | `KBGit`, spec `git.md` |
| App shell (sidebar, list, inspector, ⌘O, ⌘K, ⌘N, ⌘D) | ✓ | `App/Shell`, spec `app-shell.md` |
| Editor polish (completion, embeds, frontmatter, disk changes) | ✓ | `Editor/`, spec `editor.md` |
| Inbox decide queue + bankruptcy, rename/move with link rewriting | ✓ | `KBCapture.InboxQueue`, `KBIndex.RenameService`, spec `inbox.md` |
| Gate: Claude Code answers through `granite-mcp` | ◐ you: sign the `claude` CLI in (decision 0004) | |
| Gate: 7 days in granite | ◐ you | |

## Phase 2: grounded memory
| Item | Status | Where |
|---|---|---|
| `state.sqlite`: audit log, search events, metric snapshots | ✓ | `KBIndex.StateDatabase` |
| Model router: labels, taint, budget, routes (on-device, PCC, Claude, MLX) | ◐ built; Claude needs your key; MLX is opt-in (Settings) | `KBAI`, `KBAIMLX.MLXLanguageProvider`, spec `model-router.md` |
| Hybrid search (BM25 + vectors + rerank) in the app and `granite-mcp`; background embedding | ✓ | `App/Semantic.swift`, `App/MCPHelper`, spec `hybrid-search.md` |
| Re-find eval harness on `.granite/eval/retrieval.jsonl` | ◐ harness exists (`granite-ml bench`); you: write 20+ queries | |
| Grounded Q&A with verifier, abstention, Socratic mode | ✓ | `KBAI.GroundedQA`, `App/Shell/AskView.swift`, spec `qa.md` |
| Inline related items (≤ 3 ghost links), acceptance tracking, auto-pause | ✓ | `Editor/src/related.ts`, `App/Related.swift`, spec `related.md` |
| Proposal queue v1 (`AI/Proposals/`, accept/edit/reject, `AI/log.md`, cap 25, auto-pause) + see-also link proposals | ✓ | `KBCore.Proposal`, `KBIndex.ProposalStore`, `KBIndex.SeeAlsoJob`, `App/Shell/ProposalsView.swift`, spec `proposals.md` |
| Papers: native PDF import (+ OCR), PDF view, highlights to blocks, jump to cited passage (Zotero deferred, 0005) | ✓ | `KBPapers`, `App/Papers`, decision 0008, spec `papers.md` |

## Phase 3: compounding loops
| Item | Status | Where |
|---|---|---|
| Claim ledger: promote, supersede, history view | | |
| FSRS prompts (`> [!prompt]`), `reviews.jsonl`, review UI, "Make prompts" | | `KBReview` |
| Lint (deterministic) + nightly digest, 3 a.m. scheduler | | |
| Weekly Socratic review session | | |
| Metrics dashboard + weekly `AI/Metrics/YYYY-Www.md` | | |
| Enrichment: Crossref, OpenAlex, Semantic Scholar (on request) | | |
| Docling extraction for "study" papers (if installed) | | |
| MCP `propose_change`, `create_derived_note` | | |
| Budget enforcement (alert, hard stop for background jobs) | ✓ (in the router) | `KBAI.Router` |

## Phase 4: edge features
| Item | Status | Where |
|---|---|---|
| Code decisions: repo scan, ADR import, commit trailers, decision proposals | | `KBCode` |
| Literature-graph expansion (OpenAlex references and cited-by, ranked by your claims) | | |
| Trails (`kind: trail`), candidate trails as proposals | | |
| Contradiction detection between held claims | | |
| "New source touches a held claim" alerts | | |
| Quarterly belief diff | | |
| App Intents entities: Spotlight and Siri | | |
| Web clipper (Defuddle in a hidden web view) | | |
| Scoped LLM wiki under `AI/Wiki/<domain>/` | | |

## Waiting on you
- Sign in the `claude` CLI and run the MCP smoke test (decision 0004).
- Editor checks by hand: CJK IME, drag and drop, VoiceOver (decision 0003).
- Hotkey and Shortcuts capture by hand (`capture.md`).
- 20+ re-find queries in `.granite/eval/retrieval.jsonl`.
- Import a few real papers (⌘K "Import PDF…" or drop them on the window) and check the extracted text.
- Decide on link proposals for a few weeks: the acceptance rate tunes (and can pause) see-also.
- Optional: a Claude API key (Settings) for the cloud routes; a Developer ID team for PCC (decision 0004).
