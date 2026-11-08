# granite: master plan

A personal, native macOS knowledge base that compounds. Written 2026-11-08 from the research in `docs/research/` and nothing else.

**How to read the tags.** `[R note]` marks a research finding and the note it came from: `zotero`, `ai` (ai_layer), `stack` (language_stack_decision), `mac` (mac_app_foundation), `features` (landscape_features), `rep01` and `rep02` (the two reports), `corpus` (research-notes/02 ideal_corpus_first_principles). `[D]` marks a design decision I made. `[verify]` marks something the research could not confirm, which a spike has to settle before you build on it. Effort figures and performance targets are my estimates, not research.

---

## 1. Name and thesis

**Name: granite.** Granite forms when magma cools slowly, deep underground, into one of the hardest and most durable rocks there is. It is made of distinct crystals (quartz, feldspar, mica) that stay visible and identifiable inside the whole, which is the provenance principle in stone: every piece keeps its origin, and together they make something you can build on for decades. `[D]`

**Thesis.** Most knowledge tools are good at storage, and storage is not what compounds. The research says the variable that matters is authorship plus an output loop. One Obsidian user who audited 3.5 years of notes found only 21 permanent notes, and their latest 90 days of inflow was 79 clippings, 142 AI items and 1 note of their own `[R rep01]`. Luhmann's slip-box produced roughly one book per hundred read `[R rep01]`. Anthropic's January 2026 trial found AI hurts mastery through passive delegation (17% lower, d ≈ 0.74) and not through being present, since engaged users scored 65–86% `[R rep02]`. granite's edge comes from four properties that grow more valuable with every year of data and that no vendor can sell you or take back, because they live in your files:

1. **Legible provenance.** Every file and every AI sentence says where it came from, so you can trust what the corpus returns without checking. This is the extended-mind "endorsed on retrieval" condition `[R rep02]`.
2. **Time.** Claims are dated and superseded, never overwritten, so you can see how your thinking changed. Hindsight bias means only an external, timestamped record can show you that `[R rep02]`.
3. **A cross-type graph.** Paper → claim → idea → decision → commit, in one typed graph. No product found spans literature tools, PKM and code memory `[R features]`.
4. **A grounded personal research agent.** It answers from your own corpus with script-verified passage citations, runs mostly on-device, asks before it tells, and proposes changes instead of making them `[R ai]` `[R features]`.

---

## 2. Non-negotiable principles

| # | Principle | What it means in granite | Basis |
|---|---|---|---|
| 1 | **File over app** | Markdown plus flat YAML is the truth. The vault stays Obsidian-compatible (`[[wikilinks]]`, `![[embeds]]`, `^block-ids`, properties, callouts). granite never writes `.obsidian/`. `index.sqlite` lives outside the vault and can be deleted and rebuilt at any time. | `[R mac]` `[R rep01]` Logseq's storage-model migration is the cautionary tale `[R stack]` |
| 2 | **Provenance on everything** | Every file carries `origin: human \| source \| ai \| ai-accepted`. Folders partition by origin. Accepting an AI proposal is a recorded endorsement event. | `[R rep02]` `[R corpus]` |
| 3 | **AI writes only to the derived layer** | Models and agents write only to `AI/`. Changes to anything else arrive as proposals in `AI/Proposals/`. No agent renames or moves a file. | `[R rep02]` `[R ai]` |
| 4 | **Evidence comes only from human and source material** | Retrieval for answers excludes `AI/` by default, which prevents provenance collapse, where the corpus starts citing its own summaries. | `[R rep02]` `[R corpus]` |
| 5 | **Socratic by default** | Thinking features ask for your position first. "Just tell me" is an explicit mode, and its use is logged. | `[R rep02]` RCT; `[R ai]` |
| 6 | **Supersede, never overwrite** | Beliefs change through a new dated claim that `supersedes` the old one. Git keeps everything else. | `[R rep02]` bi-temporal model |
| 7 | **Local-first, private by folder** | An `ai:` label (`cloud \| pcc \| local \| none`) is inherited from folder policy and enforced in code at the router and MCP boundary, never in prompts. The strictest label in a request wins. | `[R ai]` |
| 8 | **Instant capture, prompted processing** | Capture has zero required fields and takes under a second. One cheap nudge toward processing follows (a "why I saved this" line), and inbox items decay into a decision queue. | collector's fallacy `[R features]` `[R rep01]` |
| 9 | **Stable identity** | A ULID `id:` in frontmatter survives renames. `^block` IDs go only on blocks something cites. | changed results hamper re-finding `[R corpus]` |
| 10 | **Precision over volume** | AI suggestions run on a fatigue budget: at most 3 inline link suggestions per note and at most 25 open proposals. A feature whose acceptance rate stays under 10% gets paused. | endorsement at scale turns into rubber-stamping `[R corpus]`; kill threshold `[R ai]` |

**Anti-features (do not build)** `[R features]` `[R rep01]`:
- A general schema or template builder. Tana's and Capacities' configuration cliff is the complaint. The types are hard-coded.
- An infinite canvas as primary storage. Canvas, if it ever exists, is a view over existing objects.
- Passive screen or audio lifelogging (Rewind died, and its value is unproven).
- Open-world AI answers without passage citations.
- Related items hidden in an inspector panel. MacStories admitted DEVONthink's See Also "not used much" there.
- A graph-view hairball as navigation.
- Bulk auto-linking, AI-written evergreen notes, unreviewed AI flashcard decks.
- Cloud-only storage and vendor memory formats.

---

## 3. Stack decision

**Decision: Swift 6 / SwiftUI + AppKit as the primary stack, with one contained TypeScript island.** This is option A′ from the research, which scored 86/100 against 80 for a Rust core with a SwiftUI shell, 77 for pure Swift, 75 each for Tauri and Electron, 73 for a Swift app with a Python or TS sidecar, and 53 for GPUI `[R stack]`. The deciding factors were first-class access to Foundation Models, MLX Swift, App Intents, Spotlight, PDFKit and extensions (all reachable only through Swift shims from other stacks), together with CodeMirror 6 being the strongest large-document Markdown editor `[R stack]`. Sensitivity: if Apple ML and extensions stopped mattering, Tauri and Electron would draw level. They do matter here.

| Language | Share | Exact role |
|---|---|---|
| **Swift 6** (strict concurrency) | ~85–90% | App shell, vault model, FSEvents watcher, Markdown and YAML parsing for the index, GRDB index with FTS5 and sqlite-vec, embeddings and rerank (MLX Swift), Foundation Models routing, Claude clients, Zotero client, PDFKit, App Intents, Spotlight, git service, `granite-mcp` and `granite-cli` executables |
| **TypeScript** | ~10–15% | The CodeMirror 6 editor bundle in a `WKWebView` (live preview, wikilink and tag completion, embeds), the Defuddle bundle for clipping, and later the Safari extension content script. Built with Vite and pnpm, tested with Vitest. No Node runtime ships. |
| **Python** | dev-time only | MLX conversions and `apple-fm-sdk` prompt evals. Optional external CLI extractors (Docling) invoked as a subprocess per paper, never as a resident sidecar `[D]`. |
| **Rust** | deferred | Escape hatch only. If FTS5 or vector search fails the 100k-note benchmark, add a Tantivy indexer as a separate process (the Raycast pattern) `[R stack]`. |

**Key libraries** (check each project's latest release before adding it):

| Need | Choice | Note |
|---|---|---|
| SQLite | GRDB.swift 7.10+ with a custom SQLite build that bundles FTS5 and sqlite-vec | `grdb-vector` (sqlite-vec 0.1.7, SQLite 3.47.2) or SQLiteVecKit, both community packages, so vet them `[R mac]` `[verify]` |
| Markdown AST | apple/swift-markdown plus a custom pre-pass for wikilinks, embeds, `^ids` and callouts | `[R mac]` |
| YAML | Yams | `[D]`, not covered by the research |
| Editor | CodeMirror 6 + lezer-markdown in WKWebView (the MarkEdit pattern) | `[R mac]` `[R stack]` |
| Clipping | Defuddle in a hidden WKWebView | `[R mac]` |
| Hotkey | sindresorhus/KeyboardShortcuts | `[R mac]` |
| MCP | modelcontextprotocol/swift-sdk ~0.11 (spec 2025-11-25, Tier 3) | Port only `granite-mcp` to the Tier-1 TS SDK if it blocks you `[R ai]` `[R stack]` |
| Local ML | ml-explore/mlx-swift-lm 3.x (`MLXEmbedders`, `MLXLanguageModel`) | `[R ai]` |
| Claude | anthropics/ClaudeForFoundationModels (beta) for interactive tool flows, plus a hand-written `URLSession` Messages client (about 200 lines of SSE) for caching, citations, batches and files | `[R ai]` |
| Scheduler | FSRS, ported or vetted Swift implementation | `[R features]` `[verify]` |

**Minimum macOS: 27.0 for the app.** `[D]` The research notes disagree. The foundation note suggests a macOS 26 floor with 27 APIs behind `#available` `[R mac]`. The AI note says to decide early, because macOS 27 brings the pluggable `LanguageModel` protocol, PCC, the MLX and Claude adapters and 8K on-device context, while 26 means hand-rolling those paths `[R ai]`. You are one user on an Apple Silicon Mac that already runs macOS 27, and macOS 27 is Apple Silicon only `[R mac]`, so set the floor at 27. Gating then works structurally, not through `#available` checks:

- `KBCore`, `KBIndex`, `KBReview` and `KBZotero` declare `.macOS(.v26)` and import no OS-27 framework. They stay portable, they can be tested anywhere, and they could be reused by an iOS companion.
- Only `KBAI` and the app target import FoundationModels, MLX and the macOS 27 App Intents schema APIs. Everything goes through protocols (`ModelProvider`, `SystemIntegration`), so a provider can be swapped out.
- APIs that arrive in 27.x point releases use `if #available(macOS 27.x, *)`.
- The model is part of the OS. Re-run the prompt eval suite after every OS update `[R ai]`.

**Distribution.** `[D]` Non-sandboxed, signed locally or with Developer ID, no App Store. A non-sandboxed app avoids security-scoped bookmarks and can shell out to `git` and extractors `[R mac]`. Extensions are always sandboxed and hand data back through an App Group. Join the $99 Developer Program: extensions, App Groups and PCC's managed entitlement probably need it `[verify]`.

**Stack risks**

| Risk | Mitigation |
|---|---|
| Agents write dated Swift (`ObservableObject`, GCD, Swift 6 concurrency errors, Int/Double slips) `[R stack]` | Logic lives in SwiftPM packages tested with `swift test`. CLAUDE.md pins idioms. Apple docs stay in context, and every feature starts from a spec. |
| WKWebView editor integration: IME, undo, focus, accessibility, drag-drop `[R stack]` | Week-1 spike. Keep the bridge narrow (text, selection, commands). The editor sits behind an `EditorView` protocol so an STTextView fallback stays possible. |
| Tier-3 Swift MCP SDK | MCP is isolated in its own binary on a stable SQLite contract. Run the conformance tests, and port that one binary to TS if needed. |
| sqlite-vec packaging with GRDB `[verify]` | Day-4 spike. Fallback: in-memory brute-force cosine over a BLOB column, which takes milliseconds below 200k chunks `[R ai]`. |
| PCC entitlement outside the App Store `[verify]` | The router treats PCC as optional. Haiku or MLX takes its place. |

---

## 4. Architecture

### 4.1 Repository and modules

```
granite/
  project.yml                 # XcodeGen; nobody hand-edits .pbxproj
  CLAUDE.md                   # repo rules for agents (§9)
  App/                        # granite.app: thin SwiftUI/AppKit target
    Scenes/ Views/ Bridges/   # NavigationSplitView, palette, PDF view, editor host
    Intents/                  # App Intents + AppEntities (capture, search, open)
    Resources/editor/         # built CM6 bundle (output of Editor/)
  Packages/
    KBCore/        # vault model, types, frontmatter, parser, IDs, policy, safe writer
    KBIndex/       # GRDB + custom SQLite, schema, FSEvents watcher, reconcile, chunker, queries
    KBReview/      # FSRS, review log replay, prompt extraction
    KBZotero/      # local API client, sync cursor, literature-note renderer, enrichment, extractors
    KBCapture/     # capture service, inbox writer, Defuddle runner, URL scheme
    KBAI/          # router, providers, embedder, reranker, retriever, verifier, proposals, jobs, audit
    KBCode/        # repo scan, ADR import, commit linking (Phase 4)
    KBTestSupport/ # fixture-vault generator, golden-file helpers
  Tools/
    granite-mcp/    # stdio MCP server (executable target)
    granite-cli/    # index / search / eval / lint from the terminal; the agents' main lever
  Editor/          # TypeScript: CM6, Vite, Vitest
  Fixtures/        # small golden vaults + synthetic retrieval eval set
  Extensions/      # Share extension, Safari clipper (Phase 4, optional)
```

Dependency rule `[D]`: `KBCore ← KBIndex ← {KBReview, KBZotero, KBCapture, KBCode} ← KBAI ← App`. Only `KBAI` and `App` import FoundationModels or MLX. `granite-mcp` links `KBCore`, `KBIndex` and the retrieval part of `KBAI`, and opens the database read-only.

### 4.2 Processes

```
                ┌─────────────────────── granite.app (Swift 6, non-sandboxed) ───────────────────────┐
 hotkey/menu ──▶│ SwiftUI+AppKit shell │ WKWebView CM6 editor │ PDFKit │ MenuBarExtra │ App Intents │
 Shortcuts  ───▶│ VaultStore (@MainActor @Observable) ◀── GRDB ValueObservation                      │
                │ actor FileWatcher (FSEvents) ─▶ actor Indexer ─▶ index.sqlite (WAL: FTS5+vec0)      │
                │ KBAI: Retriever · ModelRouter · Verifier · ProposalWriter · Scheduler · AuditLog   │
                │ KBZotero ──HTTP──▶ Zotero 10  localhost:23119/api                                   │
                │ GitService ──Process──▶ /usr/bin/git        Extractors ──Process──▶ docling (opt.) │
                └────────────────────────────────────────────────────────────────────────────────────┘
  ~/Vault (Markdown+YAML, git repo) ◀── NSFileCoordinator writes ── granite, Obsidian, Claude Code, git
  granite-mcp (stdio, in bundle) ── read-only ──▶ index.sqlite ; writes only AI/Proposals/*.md
        ▲ launched by Claude Code / Claude Desktop
  Models: Apple on-device FM (system process) · MLX (in-process) · Apple PCC · Claude API (HTTPS)
```

granite keeps running as a menu-bar app when its windows close, so nightly jobs run in-process under `NSBackgroundActivityScheduler` `[D]`. The concurrency model is a `@MainActor @Observable VaultStore` per vault, `actor Indexer`, `actor FileWatcher`, and a GRDB `DatabasePool` in WAL mode. Lists are SQL-backed and paged, never all notes held in memory. Skip TCA `[R mac]`.

### 4.3 On-disk vault layout

This reconciles the four-layer vault from report 02 `[R rep02]` with your additional needs. Folders are by type, never by topic `[R rep01]`.

```
~/Vault/                     # local folder, git repo, NOT in iCloud (§10)
  AGENTS.md                  # rulebook for any agent; CLAUDE.md = "@AGENTS.md"
  .claude/settings.json      # deny rules for Claude Code sessions in the vault
  .granite/                   # vault-level, versioned, human-owned governance
    policy.yaml              # folder → ai label, origin default, agent rights
    reviews.jsonl            # append-only FSRS review log (truth for scheduling)
    eval/retrieval.jsonl     # your personal re-find set (private)
  Inbox/                     # zero-friction captures: "YYYY-MM-DD HHmm.md"
  Notes/                     # HUMAN layer: evergreen notes, claims, decisions, trails, outputs
  Daily/                     # YYYY-MM-DD.md
  Papers/                    # one literature note per Zotero item (managed region + your region)
  References/                # books, people, tools, talks: one note per real thing
  Clippings/                 # RAW web layer (Web Clipper / Defuddle), trust: untrusted
  Code/                      # one hub note per repo + code-decision records
  Projects/                  # project hub notes (only when one has enough material)
  AI/                        # DERIVED layer: regenerable, deletable
    index.md  log.md         # agent-maintained catalog; append-only operations log
    Digests/  Synthesis/  Wiki/<domain>/  Metrics/
    Proposals/               # pending changes to non-AI files
  Private/                   # ai: local; hidden from MCP and cloud
  Archive/  Attachments/  Templates/
```

Two folders go beyond report 02, and each has a reason `[D]`:
- **`Papers/`**: granite re-renders a managed region in these notes from Zotero, so they need their own path for idempotent sync and path-based rules. Their volume (hundreds to thousands of notes) would also bury `References/`.
- **`Code/`**: the repo importer writes hub notes and imported ADR references here, and decisions keyed by repo path are easier to scope for agents working in that repo.

`Inbox/` exists because capture needs a landing zone with decay, which `Daily/` doesn't provide.

`policy.yaml` `[D]`:

```yaml
folders:
  Notes/:     { ai: cloud, origin: human,  agents: propose }
  Daily/:     { ai: pcc,   origin: human,  agents: propose }
  Inbox/:     { ai: local, origin: human,  agents: propose }
  Papers/:    { ai: cloud, origin: source, agents: propose, managed: zotero }
  Clippings/: { ai: cloud, origin: source, agents: none, trust: untrusted }
  Private/:   { ai: local, origin: human,  agents: none, mcp: hidden }
  AI/:        { ai: cloud, origin: ai,     agents: write, evidence: false }
budget: { monthly_usd: 20, alert_usd: 15, hard_stop_usd: 25 }
repos: [ "~/code/granite" ]
```

### 4.4 Object types and typed links

The set is small and fixed `[D]`, following the research's advice to hard-code the owner's types instead of building a schema editor `[R features]`.

| `type` | Folder | Origin | Purpose |
|---|---|---|---|
| `note` | Notes/, Inbox/ | human | Your writing. `kind: evergreen \| essay \| capture \| trail \| output` |
| `claim` | Notes/ | human / ai-accepted | One assertion you hold, with `status`, `confidence`, `as_of`, `supersedes` |
| `decision` | Notes/, Code/ | human | ADR-style record. `domain: code \| research \| life`. A code-decision is `domain: code` plus `repo` and `commits` |
| `source` | Papers/, References/ | source | An outside thing. `kind: paper \| book \| article \| talk \| tool` |
| `clipping` | Clippings/ | source | Raw captured text, untrusted |
| `person` | References/ | human | Authors, collaborators |
| `project` | Projects/, Code/ | human | An effort or a repo |
| `daily` | Daily/ | human | Time anchor |
| `synthesis`, `digest`, `proposal` | AI/ | ai | Machine types, never evidence by default |

**Typed relations** live in flat frontmatter as lists of links (Obsidian properties don't support nesting `[R rep01]`). Only the forward direction is stored, and the index computes inverses `[D]`:

`supports`, `contradicts`, `supersedes`, `derived_from` (inspired by), `implemented_in` (commits/repos), `about` (person/project), `source` (citation with locator). Plain inline wikilinks are untyped `links`. The edge vocabulary comes from `[R features]`.

### 4.5 Frontmatter schema

```yaml
# Notes/Hybrid retrieval beats embedding choice.md
---
id: 01JC9Q7Z5W3K8M2R4T6V8X0Y1A
type: claim
origin: human
created: 2026-11-08
as_of: 2026-11-08
status: held                 # proposed | held | revised | superseded | retired
confidence: 0.7
supersedes: ["[[Embedding model choice drives retrieval quality]]"]
source: ["[[anthropic2024contextual#^z-7HQ2KX9P]]"]
supports: []
contradicts: []
tags: []
---
Hybrid search plus reranking matters more than which embedding model you pick.
```

```yaml
# Papers/anthropic2024contextual.md  (literature note)
---
id: 01JC9R...
type: source
kind: paper
origin: source
title: "Introducing Contextual Retrieval"
citekey: anthropic2024contextual     # Zotero 8+ native citationKey
zotero_key: ABCD2345                  # the real join key
doi: ""
authors: [Anthropic]
year: 2024
status: noted                         # unread | reading | noted | studied
ai: cloud
---
## My take
(your words: the only part that counts as origin: human)

<!-- granite:zotero:begin (managed, regenerated; edits here are overwritten) -->
## Annotations
> Prepending context to chunks cut retrieval failures by 35%. ^z-7HQ2KX9P

p. 3 · [open in Zotero](zotero://open-pdf/library/items/ATTKEY01?page=3&annotation=7HQ2KX9P)
Comment: compare with heading-path prefixes
<!-- granite:zotero:end -->
```

```yaml
# AI/Synthesis/retrieval-quality.md
---
type: synthesis
origin: ai
model: sonnet-5.5
route: cloud
generated_at: 2026-11-08T03:12:00Z
prompt_hash: 9f2c…
sources: ["[[anthropic2024contextual#^z-7HQ2KX9P]]", "[[Hybrid retrieval beats embedding choice]]"]
verified: "14/14"
---
```

Rules `[D]`:
- **`id`.** granite stamps it on files it creates. For files created elsewhere (Obsidian, Web Clipper), it stamps the ID lazily, the first time something cites the file, links to it with a typed relation, or targets it with a proposal. That avoids rewriting thousands of your files on first launch.
- **Clippings.** granite accepts Obsidian Web Clipper's default properties (`source`, `author`, `published`, `created`) and adds `type`, `origin` and `trust: untrusted` on first index `[R mac]`.
- **Accepted AI text.** When you accept AI text into a human note, the file keeps `origin: human`. The proposal file records the endorsement (block IDs, timestamp), and the editor shows a faint gutter mark on accepted spans, drawn from the index. Once you edit a span, it's yours.

### 4.6 SQLite: two databases

`index.sqlite` is disposable: bump the schema version and rebuild. `state.sqlite` is not knowledge, but it's worth keeping: audit log, search events, metric snapshots. Both live in `~/Library/Application Support/granite/<vault-id>/`, never in the vault `[R mac]`.

```sql
-- index.sqlite (sketch)
CREATE TABLE objects(rowid INTEGER PRIMARY KEY, id TEXT UNIQUE, path TEXT UNIQUE,
  type TEXT, kind TEXT, origin TEXT, ai_label TEXT, status TEXT, title TEXT,
  created TEXT, mtime REAL, size INT, hash BLOB, parsed_at REAL);
CREATE TABLE props(obj INT, key TEXT, v_text TEXT, v_num REAL, v_date TEXT);
CREATE TABLE tags(obj INT, tag TEXT);
CREATE TABLE links(src INT, target_text TEXT, dst INT NULL,   -- unresolved kept
  rel TEXT, anchor_heading TEXT, anchor_block TEXT, line INT);
CREATE TABLE blocks(id INTEGER PRIMARY KEY, obj INT, block_id TEXT, kind TEXT,
  heading_path TEXT, start_line INT, end_line INT, text TEXT, hash BLOB, origin TEXT);
CREATE VIRTUAL TABLE blocks_fts USING fts5(text, heading_path,
  content='blocks', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
CREATE TABLE chunks(id INTEGER PRIMARY KEY, obj INT, first_block INT, last_block INT,
  prefix TEXT, text TEXT, tokens INT);
CREATE VIRTUAL TABLE chunks_vec USING vec0(embedding float[512]);   -- rowid = chunks.id
CREATE TABLE embed_meta(model_id TEXT, dim INT, chunker_version INT);
CREATE TABLE claims_x(id INTEGER PRIMARY KEY, block INT, text TEXT, polarity INT,
  entity TEXT, as_of TEXT, extractor TEXT);          -- derived propositions, never truth
CREATE TABLE proposals(id TEXT PRIMARY KEY, path TEXT, kind TEXT, feature TEXT,
  target INT, status TEXT, created TEXT, decided TEXT);
CREATE TABLE prompts(block INT PRIMARY KEY, due TEXT, stability REAL, difficulty REAL);
CREATE TABLE zotero_sync(server_id TEXT, library_version INT);
CREATE TABLE zotero_items(key TEXT PRIMARY KEY, version INT, obj INT,
  attachment_key TEXT, pdf_path TEXT);

-- state.sqlite (kept, backed up by Time Machine)
CREATE TABLE audit(ts, route, model, task, in_tok, out_tok, usd, note_ids, prompt_hash);
CREATE TABLE search_events(ts, query, opened_obj, rank, ms_to_open);
CREATE TABLE metrics(week, key, value);
```

Prompt scheduling state is rebuilt by replaying `.granite/reviews.jsonl`, so review history stays in files `[D]`. Losing the Zotero sync cursor costs only an idempotent full re-pull.

### 4.7 File watching and reconcile

From `[R mac]`, adopted as is:
- **Events.** One FSEvents stream on the vault root, with the last event ID persisted so changes made while the app was closed replay on launch. Debounce 100–300 ms per path.
- **Change detection.** Rows store `mtime`, `size` and a content hash. Launch does a stat walk and re-parses only changed hashes, and a nightly full reconcile catches anything FSEvents missed. Atomic saves (delete+create pairs from Obsidian, git, agents) resolve by path and hash.
- **granite's own writes** go through `NSFileCoordinator`, with hashes remembered so the echoed event is ignored.
- **External edit to an open note.** A clean buffer reloads silently. A dirty one gets a keep-mine / take-theirs / three-way-merge banner.
- **Parsing** runs in a `TaskGroup` bounded to performance cores, 500–1,000 files per transaction.

The editor bridge `[D]`: Swift owns all file I/O. The CM6 bundle receives text plus decoration data (resolved links, block IDs, accepted-AI spans, inline suggestions) and returns debounced changes and the selection over a typed message channel (`WKScriptMessageHandler`, `callAsyncJavaScript`).

---

## 5. Zotero integration

**Split of responsibilities** `[R zotero]`. Zotero 10 (released 2026-08-17) has a strong reader (Reading Mode, Read Aloud, mobile annotation), translators, sync and word-processor citations, and no built-in AI. Replacing it would be years of work for little gain.

| Zotero owns | granite owns |
|---|---|
| Capture (Connector, DOI/ISBN import), canonical metadata, citekeys | Literature notes with your own take, rendered from annotations |
| PDF/EPUB storage and sync, reading and annotating on Mac, iOS and Android | Claims linked to annotation blocks, cross-paper synthesis, contradiction checks |
| Word and Google Docs citations, CSL rendering | Embedding-based search over your papers and notes together |
| | Enrichment beyond Zotero (OpenAlex topics, S2 TLDRs), literature-graph expansion, spaced review |

**Integration surfaces**

| Surface | Use | Details |
|---|---|---|
| **Local API reads** (`http://localhost:23119/api/users/0/…`) | Primary | Enable "Allow other applications…" or every call gets `403`. Incremental pull with `items?since=<v>&format=json&include=data,citation`. Persist `Zotero-Server-ID`; a `412` means discard versions and resync. Results are unpaginated. `/items/<key>/file/view/url` returns the PDF path, `/fulltext` the text cache. Annotations are child items of attachments `[R zotero]`. Annotation JSON field names are `[verify]`. |
| **Local API writes** (Zotero 10+) | Narrow write-back | `POST /api/local/authorize` with `{appName}` and the `Zotero-Server-ID` header. Choose **Always Allow** (otherwise the key is single-use) and store the 32-char key in the Keychain. Keys aren't scoped, so granite limits itself: it adds tags `granite:noted` / `granite:claimed` and one child note with a `granite://open?id=` backlink. It never edits metadata or annotations. The authorize dialog is limited to 5 per minute `[R zotero]`. |
| **Native `citationKey`** (Zotero 8+) | Filenames, display | BBT is optional, kept only if you want `item.bibliography` or pandoc. Key everything on `zotero_key`, never citekey, because BBT a/b suffixes can swap `[R zotero]`. |
| **Direct SQLite** | Fallback only | When Zotero isn't running and you need a bulk first import: copy `zotero.sqlite` (or the `.bak`) and read the copy. Never open the live file, because of the exclusive lock and possible schema changes `[R zotero]`. |
| **Deep links** `zotero://select/…`, `zotero://open-pdf/…?page=&annotation=` | Jump from a citation to Zotero | `[verify]` in the Zotero spike |
| **translation-server** (Docker, :1969) | Not used `[D]` | Too heavy for one Mac. Add papers through Zotero itself. |
| **Enrichment** | Phase 3 | Crossref polite pool (`mailto`; single-DOI 10/s), OpenAlex (key required; free $1/day; singleton lookups reportedly free, so avoid list queries), Semantic Scholar (key, 1 RPS) `[R zotero]` |

**Paper-ingest pipeline** `[D]`, built on the patterns in `[R zotero]` `[R ai]` `[R mac]`:

1. **Detect.** Pull `since=` on app focus and every 10 minutes while Zotero is running.
2. **Stub.** Create or refresh `Papers/<citekey>.md`. Only the region between `granite:zotero` markers is regenerated, keyed by annotation key, so your edits outside it survive. That solves the "without losing manual edits" problem the Obsidian bridges struggle with `[R zotero]`. Highlights become blocks `^z-<annotationKey>` with page and deep link. Your Zotero comments count as human text.
3. **Text for search.** Local API `/fulltext` (Zotero's ft-cache) → heading-aware chunks with a `title > section` prefix → embeddings. This is cheap and covers every paper.
4. **Structure, for papers you mark "study".** Run Docling as an external CLI on the PDF and cache the Markdown in Application Support (rebuildable, outside the vault). The research favors Docling for tables, Marker for LaTeX and multi-column layouts, and GROBID for references `[R zotero]`. Start with Docling, test Marker on 10 of your own papers, and skip GROBID because OpenAlex supplies references by DOI. Scanned PDFs without an ft-cache go through Vision OCR (`OCRTool` or `VNRecognizeTextRequest`) `[R ai]` `[R mac]`.
5. **Claims.** Propose 3–5 candidate claims from your highlights and comments into `AI/Proposals/`. Each accepted claim becomes a `claim` file with `source: [[citekey#^z-…]]`.
6. **Touch check.** Compare the new paper's chunks against your held claims. Matches above a threshold get an NLI check, and hits go into the next digest as "touches claim C".
7. **Write back.** Tag `granite:noted` in Zotero.

**Failure handling**

| Failure | Response |
|---|---|
| Zotero not running / connection refused | Queue and retry on next focus; show "Zotero offline" in the status bar; search keeps working from the index |
| `403` (local API disabled) | One-time banner with the exact setting path |
| `412` server-ID mismatch | Drop cached versions, full idempotent resync |
| `429` on authorize | Back off; never loop the dialog |
| PDF missing (download-as-needed mode) | Use `/fulltext`; offer "Open in Zotero to download" |
| No ft-cache, image-only PDF | OCR path, flagged `text: ocr` |
| Citekey changed | Rename the file (granite's own rename, links rewritten); ID and `zotero_key` unchanged |
| Zotero release changes behavior (6–10 week cadence) | Use HTTP APIs only; log `Zotero-API-Version` and `Zotero-Schema-Version`; a contract test runs against your live library weekly |

---

## 6. AI layer

### 6.1 Model routing

All routes sit behind Foundation Models' `LanguageModelSession`, with `Tool` and `@Generable`, through the macOS 27 `LanguageModel` protocol. Routing is one switch, not four code paths `[R ai]`. The raw Messages client is used where Claude-specific features are needed (caching, citations, batch).

| Task | `cloud` notes | `pcc` notes | `local` notes | Why |
|---|---|---|---|---|
| Tag, title and type suggestions, inbox triage, "why saved" helper | Apple on-device | same | same | Fits in 4–8K context, ~85 tok/s, no download `[R ai]` |
| Link-suggestion justifications (≤3) | Apple on-device | same | same | Short `@Generable {target, reason, anchor}` |
| Embeddings | EmbeddingGemma 308M via MLX, 768→512 Matryoshka | same | same | <200 MB, 2K ctx `[R ai]` |
| Rerank | Qwen3-Reranker-0.6B via MLX, top 30 | same | same | `[R ai]` `[verify]` MLXEmbedders support |
| Contextual prefix for long PDFs | Apple on-device | same | same | Bounded summarization `[R ai]` |
| Grounded Q&A | Haiku 5.5; Sonnet 5.5 on "deep" | PCC (32K, quota) → else MLX | MLX Qwen3-8B / Gemma 4 E4B (opt-in) | `[R ai]` |
| Socratic weekly review | Sonnet 5.5 | PCC | MLX | |
| Claim extraction, contradiction NLI | Sonnet 5.5 **Batch** | MLX overnight | MLX overnight | Batch is 50% off; PCC quota can't carry batch jobs `[R ai]` |
| Nightly digest | Sonnet 5.5 Batch | MLX | MLX | |
| Literature synthesis (many papers) | Opus 5.5 with citations + 1h cache | not offered | not offered | Quality-critical; local models would need a warning |
| Quarterly belief diff | Opus 5.5 | MLX | MLX | |

Label semantics `[D]`: `cloud` allows any route. `pcc` allows Apple PCC plus local, but no third-party cloud. `local` means on-device FM or MLX only. `none` means no generative model and no vector embedding, only full-text search. The router computes the strictest label across every chunk in a request, and derived notes inherit it (taint). If PCC's quota runs out, the request degrades to local with a persistent notice `[R ai]`.

### 6.2 Retrieval pipeline

```
query
 → (optional) on-device query rewrite / expansion
 → FTS5 BM25 top 50  ∥  vec0 kNN top 50          # chunks ≈ 900 tokens, heading-aware, code blocks intact
 → RRF fusion (k = 60)
 → Qwen3-Reranker-0.6B over top 30
 → 1-hop expansion: wikilinks, backlinks, typed relations, shared `source`
 → light re-rank, then filters: ai-label taint, evidence scope (exclude AI/ unless asked), Private/ policy
 → context assembly with chunk IDs + origin badges (human above source above ai)
 → abstain ("I have no note on that") if the top rerank score is under a threshold tuned on the eval set
```

This follows qmd's design and Anthropic's contextual-retrieval results (−35% failures with contextual prefixes, −49% adding contextual BM25, −67% adding a reranker) `[R rep02]` `[R ai]`. Use wikilinks as the graph, no GraphRAG: independent re-evaluations cut its reported gains sharply `[R rep02]`. Each vector row records `model_id`, `dim` and `chunker_version`, so a model change triggers a background re-embed instead of mixing vector spaces.

### 6.3 Citation verification

- **Claude route.** Send retrieved chunks as `document` blocks with citations on. The response carries `cited_text` plus locations. Citations can't be combined with structured outputs in the same request, so Q&A uses citations and extraction tasks use structured outputs `[R ai]`.
- **Local route.** A `@Generable` answer schema of `[{sentence, chunk_id, quote}]`.
- **Verifier** (Swift, deterministic, route-independent). The chunk ID must exist. The quote must match the source after normalization, exactly or with ≥0.9 token overlap. Unverified sentences are greyed out with "unsupported" and never presented as fact. The pass rate is a tracked metric `[R ai]`.

### 6.4 Proposal queue

Proposals are files in `AI/Proposals/` (diffable, writable by `granite-mcp` and by Claude Code) and are indexed in the `proposals` table for the queue UI `[D]`, merging the file approach of `[R rep02]` with the SQLite table of `[R ai]`.

````markdown
---
type: proposal
kind: link            # link | edit | claim | merge | trail | prompt | tag | rule
target: "[[Hybrid retrieval beats embedding choice]]"
feature: see-also
origin: ai
model: on-device
status: open          # open | accepted | edited | rejected
citations: ["[[anthropic2024contextual#^z-7HQ2KX9P]]"]
created: 2026-11-08
---
Rationale: …
```diff
+ Related: [[Contextual BM25]]
```
````

Accept, edit or reject is one keystroke each. Each decision is appended to `AI/log.md` and the proposal's frontmatter. When you correct an agent, it drafts an `AGENTS.md` amendment as a `rule` proposal. It never edits its own rules `[R rep02]`.

### 6.5 MCP server (`granite-mcp`)

A signed stdio executable at `granite.app/Contents/MacOS/granite-mcp`, with no network port `[R ai]`. Register it with `claude mcp add granite -- /Applications/granite.app/Contents/MacOS/granite-mcp`.

| Tool / resource | Behavior |
|---|---|
| `search(query, mode: hybrid\|bm25\|vector, folder?, k)` | Same pipeline as in-app; returns chunk IDs, paths, origin |
| `get_note(id\|path, range?)` | Text with frontmatter |
| `get_backlinks(id)`, `list_recent(since)` | Graph and time navigation |
| `get_citations(zotero_key)` | Literature note + annotation blocks |
| `get_claims(topic?, status?)` | Belief ledger |
| `propose_change(target, diff, rationale)` | Writes a proposal file; never edits |
| `create_derived_note(path under AI/, body, sources)` | Writes only to `AI/`, stamped `origin: ai` |
| resources `note://<id>` | Attachable notes |

Only notes labeled `cloud` are visible over MCP, because the MCP client sends content to the cloud `[R ai]`. `Private/` is invisible. Every call is logged to `audit`.

### 6.6 Prompt-injection defenses

The vault has all three parts of the "lethal trifecta": private data, untrusted clippings, and tools `[R rep02]`. Defenses are structural `[R ai]`:

- **At clip time.** Strip zero-width and bidi characters, hidden text and HTML comments. Mark the file `trust: untrusted`.
- **In prompts.** Untrusted chunks go into delimited data blocks. Instructions stay in the system or operator channel.
- **CaMeL-lite.** The pass that reads untrusted text (summarizing a clipping) runs with no tools. No side-effecting tool call may be triggered by untrusted content, and any proposal derived from it shows the triggering source.
- **Exfiltration guard.** Cloud agents get no web-fetch tool while private-labeled content is in context. AI output never auto-loads remote images, and URLs render as text until clicked.
- **Tools.** Typed Swift functions, no shell. Write access only through the proposal writer.
- **Audit.** Every model call is recorded: route, model, tokens, cost, note IDs, prompt hash (never content). The dashboard shows "what left this Mac this week".

### 6.7 Costs

Prices from `[R ai]` (Nov 2026, per MTok): Haiku 5.5 $0.10 in / $0.50 out; Sonnet 5.5 $2 / $10, cache hits $0.10, batch $1 / $5; Opus 5.5 $4 / $20. Per-operation figures are the research's arithmetic. The monthly mix is my estimate.

| Operation | Unit cost | Assumed volume | Monthly |
|---|---|---|---|
| Grounded Q&A (8K ctx, 600 out) | Haiku $0.0011 / Sonnet $0.022 | 450 (80% Haiku) | ~$2.40 |
| Nightly digest (60K in, 2K out, Sonnet Batch) | $0.07 | 30 | ~$2.10 |
| Literature synthesis (30 papers, Opus) + follow-ups on cache | $0.68 / $0.03 | 4 + 40 | ~$3.90 |
| Claim extraction (10K in, 1K out, Sonnet Batch) | ~$0.015 | 40 | ~$0.60 |
| Contradiction NLI (2K in, 200 out, Sonnet Batch) | ~$0.003 | 200 | ~$0.60 |
| Weekly Socratic review (cached context) | ~$0.23 | 4 | ~$0.90 |
| Quarterly belief diff (Opus, 200K in) | ~$0.90 | 1/3 | ~$0.30 |
| Embeddings, rerank, tagging, link reasons, prefixes | local | all | $0 |
| **Total** | | | **≈ $11/month** |

Budget `[D]`: $20/month, an alert at $15, and a hard stop at $25 for non-interactive jobs. Claude Code usage while you build the app is separate.

---

## 7. Features that compound (ranked)

Ranking follows `[R features]` Q5, adjusted for your needs. Each feature lists what it does, why it compounds, how it works, its guardrail, and its phase.

**1. Grounded Q&A with passage citations (Phase 2).** You ask a question and get an answer built only from your notes and sources, where each sentence links to a verified passage, or "I have no note on that". *Compounds:* every past capture becomes answerable, and hallucination complaints concentrate in open-world tools `[R features]`. *How:* §6.2 → §6.3, origin badges, with "include AI layer" off by default. *Guardrail:* abstention, the verifier, Socratic mode on thinking questions.

**2. Inline related items (Phase 2).** While you write, up to 3 related notes, papers or decisions appear as ghost links in the editor margin. Accepting one inserts a real link. *Compounds:* DEVONthink's See Also is the best existence proof of local similarity, but it went unused in an inspector, so this has to be inline `[R features]`. *How:* chunk vectors for the current paragraph + BM25 on titles and aliases → rerank → exclude existing links → on-device justification. *Guardrail:* cap of 3, accept/reject logged, threshold tuned, pause below 10% acceptance.

**3. Capture inbox with processing prompts (Phase 1).** A global hotkey opens a panel, you capture with no required fields, and an optional "why?" line stays focused (Esc skips it). Items older than 14 days go to a decide queue (make a note / link to an existing one / archive). A bankruptcy button moves everything older than 60 days to `Archive/`. *Compounds:* this is the direct countermeasure to the collector's fallacy `[R rep01]` `[R features]`. *How:* App Intent + `NSPanel` + MenuBarExtra + URL scheme, all through one `CaptureService`. On-device triage proposes type and links. *Guardrail:* processing never blocks capture.

**4. Literature notes from Zotero (Phase 2).** §5. *Compounds:* annotations stop being a silo and become citable blocks that claims can point to `[R zotero]`. *Guardrail:* managed region only; your take is never touched.

**5. Claim and belief ledger (Phase 3).** Promote a sentence to a `claim` file. "Supersede" creates a new claim linked to the old one (old status → `superseded`, body untouched). A per-topic view shows the history. *Compounds:* this is the unique differentiator, and nothing on the market does it `[R features]`. Over years it becomes your record of how your thinking changed. *How:* claim files + `supersedes` + git history, plus derived propositions in `claims_x` used only for matching. *Guardrail:* only claims you promote are truth. Extracted propositions never are.

**6. Spaced retrieval prompts on chosen notes (Phase 3).** The "Make prompts" command drafts Q/A as `> [!prompt]` callouts (proposals). You edit and accept them, and FSRS schedules them. Review shows the question first and asks you to recall before revealing. *Compounds:* this is the strongest evidence in the whole corpus. FSRS beat trainable SM-2 in 97.4% of collections on a ~729M-review benchmark, and Quantum Country got about 54 days of retention per prompt for about 95 minutes of review `[R features]` `[R rep02]`. *Guardrail:* only on notes you choose (Matuschak: the bottleneck is prompt authoring). Most AI-drafted cards get deleted `[R rep02]`.

**7. Nightly digest and lint (Phase 3).** At 3 a.m., changed notes are clustered and summarized with citations, and the digest lists "open questions you wrote". Lint covers orphans, unresolved links, missing properties, `as_of` older than 12 months on held claims, uncited AI sentences, AI text in the human layer without an acceptance record, stale inbox items, and new sources touching held claims. Output goes to `AI/Digests/YYYY-MM-DD.md` and proposals. *Compounds:* it puts scaffolding on the read path. Hack-Log found agent-facing notes stayed current (54% updated within 30 days) while human-facing ones didn't (0 of 134) `[R rep02]`. *Guardrail:* it writes only to `AI/`, and it stays inside the proposal budget.

**8. Code-decision records linked to commits (Phase 4).** `decision` with `domain: code`, `repo` and `commits`. The importer reads `docs/adr/` and agent memory files (CLAUDE.md, AGENTS.md) from your repos as source references. A commit trailer `Granite-Decision: <id>` links commits to decisions, and the on-device model flags decision-like commit messages and proposes a record stub where you write the *why*. *Compounds:* ADRs capture "why", which is the part that gets lost, and no tool links code decisions to the papers and notes that motivated them `[R features]`. *Guardrail:* this is a design hypothesis. The research found no sources on mining agent memory files, so judge it by whether you reopen the records.

**9. Literature-graph expansion (Phase 4).** From a seed paper, OpenAlex references and cited-by plus S2 recommendations are ranked by similarity to your held claims and notes. "Add to Zotero" hands the DOI to Zotero. *Compounds:* new reading is chosen by what you already think. Integrate rather than rebuild, because Litmaps and ResearchRabbit are consolidating `[R features]`. *Guardrail:* singleton lookups only, within the OpenAlex budget.

**10. Trails (Phase 4).** A `note` with `kind: trail`: an ordered list of links, each with one sentence of your own. The AI proposes candidate trails from Q&A sessions and clusters, and you name and endorse them. *Compounds:* Bush's associative trails are the under-built primitive, since tools have links but not trails `[R rep02]`. *Guardrail:* a trail only counts once you've named it.

**11. Weekly Socratic review (Phase 3).** A Sunday session assembles the week's daily notes, inbox, new claims and open proposals. It asks first ("What changed your mind this week?", "Which claim would you defend least?"), then raises counter-examples from your own notes. The output is your weekly note (origin human) plus proposal decisions. *Compounds:* engaged use preserves learning while passive delegation harms it `[R rep02]`, and a ritual turns fragments into claims `[R rep01]`. *Guardrail:* "tell me" is explicit and logged, and the session is judged by what you wrote, not whether it ran.

**12. Metrics dashboard (Phase 3).** §11, frozen weekly into `AI/Metrics/YYYY-Www.md` so agents and git can read it as text `[R rep02]`.

Also in Phase 4: **contradiction detection** (claim pairs with high similarity and opposite polarity → NLI → digest, never auto-resolved `[R ai]`), **quarterly belief diff** ("In March you held X, in October Y; source Z triggered it" `[R rep02]`), and **a scoped LLM wiki** under `AI/Wiki/<domain>/` for one reference domain you need to query, never for your own thinking `[R rep02]`.

---

## 8. Phased roadmap

Effort assumes one person working with Claude Code, about 25–30 focused hours a week. These are my estimates. **Phase 1 is where daily-use value starts (end of week 6). Phase 2 is where the edge starts to show (end of week 11).**

| Phase | Weeks | Scope | Done when |
|---|---|---|---|
| **0: Spikes** | 1 | Four spikes (below) + repo skeleton | All four gates pass or a fallback is chosen and written up as a decision record |
| **1: Daily driver (MVP)** | 2–6 | Vault open; sidebar, note list, CM6 editor with live preview, wikilink and tag completion, embeds; properties panel; FTS5 search, quick switcher, ⌘K palette; backlinks; daily notes; capture hotkey panel + App Intent + menu bar + URL scheme; Inbox with "why" and decay queue; in-app git auto-commit with deletion alarm; `granite-mcp` read-only (search, get_note, backlinks); `granite-cli`. Clippings come from the Obsidian Web Clipper pointed at the vault `[R mac]`. | You use granite instead of Obsidian for 7 consecutive days; capture panel appears in <300 ms; FTS p95 <50 ms on the 50k fixture; Claude Code answers a question through `granite-mcp` citing a note path |
| **2: Grounded memory** | 7–11 | MLX embeddings + hybrid + rerank + abstention; re-find eval harness; inline related items; ModelRouter, labels, taint, audit log; Zotero sync + literature notes; grounded Q&A with verifier; proposal queue v1 (link proposals); PDFKit "jump to cited passage" view | Recall@5 on your 50-query re-find set beats BM25-only by ≥10 points; citation verification ≥95%; ≥1 Q&A per day for 2 weeks; link-proposal acceptance ≥25% |
| **3: Compounding loops** | 12–17 | Claim ledger + supersede; FSRS prompts + review UI; nightly digest/lint (Batch); weekly Socratic review; metrics dashboard; enrichment (Crossref/OpenAlex/S2); Docling for "study" papers; MCP `propose_change` and `create_derived_note`; budget enforcement | 4 consecutive weekly reviews done; ≥30 held claims, ≥3 superseded; daily prompt reviews with ≥85% recall; you open the digest ≥4 days a week |
| **4: Edge features** | 18–24 | KBCode (ADR import, commit trailers, decision proposals); literature-graph expansion; trails; contradiction detection; "new source touches held claim" alerts; quarterly belief diff; macOS 27 entity schemas for Spotlight and Siri + AppIntentsTesting; optional Share extension or Safari clipper; scoped LLM wiki | First belief diff answers "what did I think in March and why did it change?" correctly from the record; a commit-linked decision found by re-find in <1 minute; 2 named trails |

**Phase 0 spikes** (gates are my targets; the research only says to measure):

| Spike | Build | Gate | Fallback |
|---|---|---|---|
| A. Editor | CM6 in WKWebView with live-preview decorations and a typed bridge; open a 50k-line Markdown file | Opens in <1 s; keystroke-to-paint p95 <16 ms; smooth scroll; CJK IME composes correctly; undo and redo cross the bridge | STTextView / TextKit behind the `EditorView` protocol `[R stack]` |
| B. Index | GRDB + bundled SQLite (FTS5 + sqlite-vec) on a generated 50k-note vault; EmbeddingGemma via MLXEmbedders; reranker | FTS-only cold index <2 min; warm-launch reconcile <3 s; hybrid + rerank p95 <800 ms; full embed overnight-able; measured chunks/s recorded | Brute-force cosine over BLOBs; Tantivy process later `[R ai]` `[R stack]` |
| C. Zotero 10 | Local API `since=` pull, annotation children, `/file/view/url`, `/fulltext`; authorize Always Allow; add a tag + child note; test `zotero://open-pdf` | Annotation fields mapped; write visible in Zotero UI; deep link opens the right page | Read-only via the API + SQLite-copy for bulk; skip write-back |
| D. MCP + models | `granite-mcp` on swift-sdk 0.11 (stdio) with `search` / `get_note`; register in Claude Code and Claude Desktop; smoke-test `LanguageModelSession` on on-device, PCC, MLX and Claude adapters | Claude Code cites a vault note through the helper; Desktop launches the helper from the bundle; PCC entitlement status known | TS MCP SDK for the helper; PCC removed from routes |

---

## 9. Building it with Claude Code

**Project generation.** XcodeGen `project.yml` (YAML is simpler for agents than Tuist's Swift manifests `[D]`), so agents never touch `project.pbxproj` `[R mac]`. The app target is thin, and nearly all logic sits in local SwiftPM packages that build and test with `swift test` without Xcode `[R stack]`.

**Agent tooling.**
- Add XcodeBuildMCP for build, run and screenshot loops: `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`. Its telemetry is on by default, so opt out.
- Or use Xcode's own bridge: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`, from a GA Xcode, not an RC `[R mac]`. Xcode 27 also ships SwiftUI agent skills `[R mac]`.
- Use `granite-cli` (`index`, `search`, `eval`, `lint`) so agents can check behavior from the terminal.

**Repo `CLAUDE.md`** (the core, about 60 lines in total):

```markdown
# granite — rules for agents
- Swift 6, strict concurrency. @Observable + @MainActor models; actors for background work;
  async/await only. Never ObservableObject, Combine, DispatchQueue, Timer.scheduledTimer.
- Explicit numeric conversions (Int/Int32/Double/Float); no force unwraps outside tests.
- Logic goes in Packages/*; App/ stays thin. Every package change ships with `swift test` passing.
- Only KBAI and App may import FoundationModels or MLX. KBCore/KBIndex stay OS-26-clean.
- Never edit project.pbxproj; edit project.yml and run `xcodegen`.
- Never touch ~/Vault. Use Fixtures/ or `swift run granite-cli fixture --notes 50000 --out /tmp/...`.
- Markdown is truth; index.sqlite is disposable — schema changes bump the version and rebuild.
- File writes go through KBCore.SafeWriter (NSFileCoordinator + echo suppression).
- AI code: no tool may write outside AI/; changes to other files are proposals.
- Before a feature: write/read the spec in docs/specs/<feature>.md. After: update it.
- When I correct you, propose an edit to this file in your summary.
- Editor/: pnpm, Vite, Vitest; the bridge protocol lives in Editor/src/bridge.ts and
  App/Bridges/EditorBridge.swift — change both together, with a round-trip test.
```

Add `.claude/settings.json` deny rules for `Edit(~/Vault/**)` and `Bash(rm -rf *)`, and a hook that runs `swift test` for the touched package after edits `[D]`. CLAUDE.md is not a security control, settings are `[R rep02]`.

**Testing strategy** `[D]` built on `[R ai]` `[R stack]`:

| Layer | Test |
|---|---|
| Parser and frontmatter | Golden-file fixture vaults (Obsidian edge cases: aliases, embeds, block IDs, callouts, unicode, CRLF, YAML lists of links); parse → serialize round-trip must be byte-identical for untouched files |
| Index | Generated 1k / 50k vaults; reconcile tests that simulate atomic saves, renames, git checkouts and external edits during indexing |
| Zotero | Recorded local-API responses as fixtures plus a weekly live contract test |
| Retrieval | `Fixtures/eval/synthetic.jsonl` in CI; your private `.granite/eval/retrieval.jsonl` run locally: Recall@5/10, MRR, nDCG@10 per variant (BM25 / vector / hybrid / +rerank / +prefix) with paired comparisons |
| AI features | Verifier unit tests; prompt evals per OS update; acceptance and edit-distance telemetry |
| Editor | Vitest for decorations and bridge; one XcodeBuildMCP UI smoke run per phase |
| Intents | AppIntentsTesting (macOS 27) `[R mac]` |

**Keeping agents productive.** One spec per feature (inputs, outputs, files touched, done-when) and one package per session. Keep Apple docs for the new APIs (FoundationModels, App Intents 27) in `docs/apple/`, because training data lags `[R stack]`. Run long jobs through `granite-cli`, and use git worktrees for parallel agents. Record every spike outcome as a decision record in your vault's `Code/`, so the product is in use on itself from week one.

---

## 10. Sync, backup and history

`[R rep02]` `[R mac]`, adapted to a Mac-first app:

- **Vault location.** `~/Vault`, a local folder, not iCloud. Never run iCloud and git on the same folder, because `.git` internals get evicted and conflicted `[R mac]`. If you later want iPhone access, follow report 02: the vault goes in iCloud with **Keep Downloaded**, plus `git init --separate-git-dir` outside iCloud and commits from the Mac only. granite must then check `ubiquitousItemDownloadingStatus` before parsing `[R mac]`.
- **Git auto-commit.** granite's `GitService` shells out to `/usr/bin/git`. It commits 5 minutes after the last change and on quit ("auto: 12 notes changed"), then pushes to a private remote. Until Phase 1 ships, run report 02's launchd script.
- **Deletion alarm.** If more than 20 deletions are staged, or any 0-byte `.md` files appear, auto-commit pauses and a notification asks you to review. Evicted or broken files look like deletions to git `[R rep02]`.
- **`.gitignore`.** `.obsidian/workspace*.json`, `.obsidian/cache`, `.trash/`, `.DS_Store`. PDFs live in Zotero storage, not the vault, which keeps the repo small (GitHub blocks files over 100 MiB). Keep attachments under 50 MiB.
- **Agents.** Bulk or scheduled agent work (Claude Code, migrations) runs on a branch or worktree with commit author `agent`, reviewed with `git diff --name-status` before merging `[R rep02]`. granite's own AI writes go to `AI/` and are committed like any other change.
- **Vault `.claude/settings.json`.** Deny `Edit/Write(./Notes/**)`, `Edit(./Clippings/**)`, `Read(./Private/**)`, `Edit(./AGENTS.md)`, `Bash(rm *)`, `Bash(mv *)` `[R rep02]`.
- **Time Machine** covers everything git doesn't, including `state.sqlite` and a damaged `.git` `[R rep02]`.
- **Restore drill.** Once in Phase 1, restore one note from git and one from Time Machine. That is report 02's stage-1 "done when".

---

## 11. Measuring the edge

No established metric says whether a knowledge base pays off `[R rep01]` `[R corpus]`. These proxies come from the research, and granite computes them automatically from the index, git and `state.sqlite`.

| Metric | Definition | Healthy signal `[D]` | Source |
|---|---|---|---|
| Own notes written | `note` + `claim` + `decision` files created or substantively revised by you per month | Rising or steady; ≥8 claims/month early on | `[R rep01]` |
| Inflow mix | Words added per month by origin (human / source / ai / ai-accepted), from git diffs | Human words ≥25% of non-AI inflow; alarm below 10% (the 142:1 pattern) | `[R rep01]` |
| Output per input | `kind: output` notes per quarter ÷ sources ingested; notes cited in outputs | Nonzero every month; Luhmann's ~1% is a humbling baseline | `[R rep01]` |
| Re-find success | Eval Recall@5; in-app share of searches with a top-5 result opened within 30 s; median time-to-refind | Recall@5 ≥0.8; time-to-refind <1 min | `[R ai]` `[R rep02]` |
| Correct abstention | Share of "no note" answers you mark correct | ≥80% | `[R corpus]` |
| Proposal acceptance | Per feature, accepted + edited ÷ shown | Pause a feature below 10% for 4 weeks | `[R ai]` |
| Citation pass rate | Verified ÷ total AI citations | ≥95% | `[R ai]` |
| Retention | FSRS recall success on due prompts | ~85–90% | `[R features]` |
| Belief motion | Claims superseded or revised per quarter | >0; zero for a year means you aren't recording changes of mind | `[D]` |
| Backlog age | Median inbox age | <14 days | `[R rep01]` |
| Data egress | Tokens and notes sent per route per week | No `local` note ever on a cloud route | `[R ai]` |

**Cadence.**
- **Daily:** inbox decide queue and due prompts (5 minutes).
- **Weekly:** Socratic review, then a 2-minute look at the dashboard.
- **Monthly:** inflow mix and output check. If own-writing is falling, cut capture, don't add features.
- **Quarterly:** belief diff, eval-set refresh (add 10 real queries), audit of AI features (keep, tune or kill).
- **Yearly:** the "40 questions" review `[R rep01]`.

---

## 12. Risks and open questions

| Risk | Mitigation |
|---|---|
| **You stop using it** (the real risk: every method's failures lack an output loop) `[R rep01]` | Phase 1 is narrow and daily. One low-bar output stream (TILs or weekly memos) starts in month one. Judge by own-writing, not features. |
| **Provenance collapse** over years | Evidence scope excludes `AI/`; origin badges; derived layer is deletable; lint flags AI text in the human layer |
| **Rubber-stamping proposals** `[R corpus]` | Hard caps, acceptance tracking, auto-pause |
| **Overbuilding before value** | The phase gates are real. Don't start Phase 3 until Phase 2's "done when" holds. |
| **Zotero cadence breaks integration** `[R zotero]` | HTTP API only, version headers, weekly contract test, read-only degradation |
| **Model drift per OS update** `[R ai]` | Prompt eval suite after each OS update; FM prompts kept small and typed |
| **Index drift from external writers** | Hash reconcile, persisted FSEvents ID, nightly full reconcile, one-click rebuild |
| **Cost creep** | Audit table, budget hard stop, Batch for nightly jobs |

The stack-level risks (editor bridge, Swift agent quality, MCP SDK tier, sqlite-vec packaging) are in §3, and injection is in §6.6.

**Research gaps to settle during the spikes and early phases** `[verify]`:
1. CM6 versus TextKit 2 on 10k+ line files. No benchmark exists. Spike A measures it.
2. sqlite-vec inside GRDB on macOS 27 (community packages only), and FTS5/vec performance at 100k notes from Swift.
3. Whether `MLXEmbedders` loads EmbeddingGemma and Qwen3-Reranker out of the box. Reranker latency on your Mac.
4. Zotero 10 annotation JSON field names, whether annotations can be *created* via the API (a forum request suggests not), and `zotero://open-pdf` deep links.
5. PCC managed entitlement for a non-App-Store app, and per-user quota size in practice.
6. Whether ClaudeForFoundationModels covers prompt caching and citations. If not, use the raw client.
7. Latest swift-sdk tag and its feature coverage, and whether Claude Desktop launches a helper from inside an app bundle.
8. On-device model context on your hardware (4K or 8K). Read `contextSize` at runtime.
9. Developer Program requirements for extensions, App Groups and PCC.
10. Defuddle's quality in a hidden WKWebView on your typical sites.
11. Docling versus Marker on your own papers.
12. Code-knowledge mining (CLAUDE.md, commits) has no research behind it. Treat it as an experiment.

**Open design questions** the literature hasn't solved `[R corpus]`. Start with the conservative choice for each: resurfacing only in the digest (no pop-ups), origin badges as the only trust UI, and extracted claims kept as proposals.

---

## 13. First 10 days

| Day | Do | Finished when |
|---|---|---|
| 1 | Safety net first: `git init` the real vault, install report 02's launchd commit script with the deletion alarm, push to a private remote, confirm Time Machine. Make `~/VaultCopy` for development. Create the `granite` repo, `project.yml`, empty packages, `CLAUDE.md`, `.claude/settings.json`. Add XcodeBuildMCP (telemetry off) or `xcrun mcpbridge`. Enable the Zotero local API. | `xcodegen && swift test` passes on empty packages; one vault note restored from git |
| 2 | Spike A: CM6 bundle (Vite), WKWebView host, typed bridge, live-preview decorations for headings, emphasis, wikilinks | A 50k-line file opens and you can type in it |
| 3 | Spike A: measure latency and scroll, test CJK IME, undo, drag-drop. Write the decision record in `Code/` | Gate pass or fallback chosen |
| 4 | Spike B: `KBTestSupport` fixture generator (50k notes); GRDB + bundled SQLite with FTS5 + vec0; parse and index | FTS cold index time and query p95 recorded |
| 5 | Spike B: EmbeddingGemma + reranker via MLX; hybrid + RRF; time the full embed | Hybrid p95 and chunks/s recorded; gate decision |
| 6 | Spike C: Zotero local API pull, annotations, file path, fulltext; authorize, write a tag and child note; test deep links | One real paper rendered as a `Papers/` note with annotation blocks |
| 7 | Spike D: `granite-mcp` stdio with `search` / `get_note` on the 50k index; register in Claude Code and Desktop; one-call smoke test of on-device, PCC, MLX and Claude sessions | Claude Code cites a fixture note; model-route matrix filled in |
| 8 | `KBCore`: frontmatter + Markdown pre-pass, object types, policy.yaml, SafeWriter; golden fixtures for Obsidian syntax | Round-trip tests green on 30 edge-case files |
| 9 | `KBIndex`: FSEvents watcher, reconcile, persisted event ID. App shell: sidebar, note list, editor opening `~/VaultCopy` | Editing in Obsidian updates granite's list within 1 s |
| 10 | Capture panel + Inbox writer + App Intent. Write your first 20 re-find queries from memory into `.granite/eval/retrieval.jsonl`. Review the spike records and freeze the Phase 1 spec. | You captured something real through the hotkey, and the Phase 1 plan is committed |

From day 11, build Phase 1 against the frozen spec, and switch your daily writing to granite the moment it can open, edit, search and capture. The vault stays plain Markdown throughout, so you can return to Obsidian on any day you need to.
