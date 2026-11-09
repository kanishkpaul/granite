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
| Claim ledger: promote, supersede, history view | ✓ | `KBCore.ClaimNote`, `KBIndex.ClaimService`, `App/Claims`, spec `claims.md` |
| FSRS prompts (`> [!prompt]`), `reviews.jsonl`, review UI, "Make prompts" | ✓ | `KBReview`, `KBAI.PromptDrafter`, `App/Review`, spec `prompts.md` |
| Lint (deterministic) + nightly digest, 3 a.m. scheduler | ✓ | `KBIndex.VaultLint`, `KBAI.DigestJob`, `App/Nightly.swift`, spec `digest.md` |
| Weekly Socratic review session | ✓ | `KBCore.WeeklyNote`, `App/Review/WeeklyReviewView.swift`, spec `weekly-review.md` |
| Metrics dashboard + weekly `AI/Metrics/YYYY-Www.md` | ✓ | `KBIndex.VaultMetrics`, `App/Review/Metrics.swift`, spec `metrics.md` |
| Enrichment: Crossref, OpenAlex, Semantic Scholar (on request) | ✓ | `KBPapers.ScholarlyClient`, spec `enrichment.md` |
| Docling extraction for "study" papers (if installed) | ◐ built; Docling not installed here | `KBPapers.DoclingRunner`, spec `enrichment.md` |
| MCP `propose_change`, `create_derived_note` (+ `get_claims`) | ✓ | `GraniteMCPKit/WriteTools.swift`, `KBIndex.ProposalFiles`, spec `granite-mcp.md` |
| Budget enforcement (alert, hard stop for background jobs) | ✓ (in the router) | `KBAI.Router` |

## Phase 4: edge features
| Item | Status | Where |
|---|---|---|
| Code decisions: repo scan, ADR import, commit trailers, decision proposals | ✓ | `KBCode`, `App/Code`, spec `code-decisions.md` |
| Literature-graph expansion (OpenAlex references and cited-by, ranked by your notes) | ✓ | `KBPapers.LiteratureGraph`, spec `literature-graph.md` |
| Trails (`kind: trail`), candidate trails as proposals, walking | ✓ | `KBCore.Trail`, `KBIndex.TrailSuggester`, `App/Trails`, spec `trails.md` |
| Contradiction detection between held claims | ✓ | `KBAI.ContradictionFinder`, digest, spec `beliefs.md` |
| "New source touches a held claim" alerts | ✓ | NLI-checked in the digest + notification, spec `beliefs.md` |
| Quarterly belief diff | ✓ | `KBAI.BeliefDiff`, spec `beliefs.md` |
| App Intents entities: Spotlight and Siri | ◐ built; check in Spotlight/Siri from the installed app | `App/Intents`, spec `app-intents.md` |
| Web clipper (Defuddle in a hidden web view) | ✓ | `Editor/src/clipper.ts`, `App/Clipper`, spec `clipper.md` |
| Scoped LLM wiki under `AI/Wiki/<domain>/` | ✓ | `KBAI.WikiBuilder`, spec `wiki.md` |

## Waiting on you
**Setup (once)**
- Install granite in /Applications (build `granite` in Xcode), open your vault, and let it index.
- Optional: a Claude API key (Settings → AI) for the cloud routes; a Developer ID team for PCC (decision 0004).
- Optional: turn on the local MLX model in Settings → AI and download it (2.3–4.6 GB) if private notes need more than the on-device model.
- Optional: add your code repositories in Settings → Code; `pipx install docling` for "Study with Docling".
- Sign in the `claude` CLI and register the MCP server: `claude mcp add granite -- /Applications/granite.app/Contents/MacOS/granite-mcp --vault ~/Vault` (decision 0004).
- A clip bookmarklet: `javascript:location.href='granite://clip?url='+encodeURIComponent(location.href)`.

**Checks only you can do**
- Editor by hand: CJK IME, drag and drop, VoiceOver (decision 0003).
- Hotkey and Shortcuts capture (`capture.md`); Spotlight and "Ask granite" in Siri (`app-intents.md`).
- Import a few real papers and check the extracted text.

**Gates (they measure your use; plan §8)**
- Phase 1: seven consecutive days in granite.
- Phase 2: 20+ re-find queries in `.granite/eval/retrieval.jsonl` (Recall@5 beats BM25 by ≥ 10 points); a Q&A a day for two weeks; link-proposal acceptance ≥ 25%.
- Phase 3: four weekly reviews in a row; ≥ 30 held claims and ≥ 3 superseded; daily prompt reviews with ≥ 85% recall; the digest opened ≥ 4 days a week.
- Phase 4: the first belief diff answers "what did I think in March and why did it change?"; a commit-linked decision re-found in under a minute; two named trails.

## Branches
Each feature is its own branch, stacked in this order (each builds on the one before), all pushed to `origin`:
`phase0/core-and-index` → `phase1/capture` → `phase1/git-autocommit` → `phase1/app-shell` → `phase1/editor-polish` → `phase1/inbox-queue` → `phase2/model-router` → `phase2/hybrid-everywhere` → `phase2/grounded-qa` → `phase2/proposals` → `phase2/related` → `phase2/papers` → `phase2/mlx-llm` → `phase3/claims` → `phase3/prompts` → `phase3/digest-weekly` → `phase3/metrics` → `phase3/enrichment` → `phase3/mcp-writes` → `phase4/code-decisions` → `phase4/trails-litgraph` → `phase4/beliefs` → `phase4/clipper-intents` → `phase4/wiki` → `final/docs`. The last branch holds everything; merging it into `main` lands the whole build.
