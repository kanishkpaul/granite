# Frontier Extensions: Upgrading an Obsidian Vault "Beyond Itself" (as of Nov 2026)

Scope note: sync/versioning, specific AI workflows and vector DB infrastructure belong to other researchers and are mentioned only in passing. About 20 searches and fetches went into these notes. Coverage is strongest on agent workspaces, the CLI and Bases, the LLM-wiki pattern, ingestion via Screenpipe and Granola, multiplayer, and DuckDB. It is weakest on recent essays by the named thinkers and on fine-tuning from notes.

## Q1. First principles: which primitives does a vault expose, and what do other systems gain by treating it as a substrate?

### Takeaway
A vault offers five primitives: (1) plain-text Markdown files, (2) `[[wikilinks]]` that form a graph, (3) YAML frontmatter, which acts as a typed property layer, (4) a filesystem path hierarchy, and (5) as of 2026, a running app that exposes an official CLI and URI API. Every frontier upgrade uses one or more of these. In 2026 the biggest change is that the first-party CLI and Agent Skills made "the vault as a substrate for agents" an officially supported use, not a hack.

### Cited Findings
- Obsidian's position is "files over apps". Steph Ango (CEO) is credited as the designer of that philosophy. — [dsebastien.net](https://www.dsebastien.net/obsidian-ai-skills-by-steph-ango/); [Medium summary](https://medium.com/@hamzakhaledlklk/obsidians-ceo-just-taught-ai-how-to-use-his-own-app-here-s-the-0-way-to-do-it-too-97acbe8cfefe)
- "Obsidian stores plain text. Claude Code reads plain text. No integration layer needed — just point Claude at your vault folder." — [HowToGeek](https://www.howtogeek.com/claude-obsidian-the-cheat-code-for-building-a-second-brain/)
- Release history of the official Obsidian CLI: early access for Catalyst members in 1.12.0 (10 Feb 2026), generally available in 1.12.4 (27 Feb 2026), and a native CLI binary that replaced calls to the Electron binary in 1.12.7 (23 Mar 2026), which made it "significantly faster". The 1.15.0 early-access build (22 Oct 2026) added URI and CLI commands for adding content under a heading. — [Obsidian 1.12 changelog](https://obsidian.md/changelog/2026-02-27-desktop-v1.12.4/); [Obsidian changelog index](https://obsidian.md/changelog/); [1.15.0 EA](https://obsidian.md/changelog/2026-10-22-desktop-v1.15.0/); [Releasebot summary](https://releasebot.io/updates/obsidian)
- CLI scope, quoted: "Anything you can do in Obsidian you can do from the command line." Command families cover search (`search`, `search:context`), daily notes (`daily:append`/`daily:read`), files, properties and tags (`property:set`), tasks, Bases (`bases`, `base:query`), the link graph (`backlinks`, `orphans`, `unresolved`), plugins and themes, the command palette (`command`), Sync, Publish and file history (`publish:add`, `history:restore`), and developer commands (`eval`, `dev:screenshot`, `dev:dom`). Output is available as json, csv or tsv, and there is a TUI. **The Obsidian app has to be running**; if it isn't, the first command launches it. The developer commands are aimed explicitly at "agentic coding tools". — [Obsidian Help: CLI](https://obsidian.md/help/cli)
- 1.12 also added a `unique` URI action, an `appendBinary` vault API and Canvas backlinks (which now count in Graph view). — [Obsidian 1.12 changelog](https://obsidian.md/changelog/2026-02-27-desktop-v1.12.4/)
- Wikipedia lists 1.14.4 (5 Oct 2026) as the stable version, while the official changelog already lists 1.15.0 early access (22 Oct 2026). — [Wikipedia](https://en.wikipedia.org/wiki/Obsidian_(software)); [Obsidian changelog](https://obsidian.md/changelog/)

### Inferences
- Primitives map to upgrade families as follows. **Files** support agents as read/write workers, git and CI, and static publishing. **Links** support graph navigation that replaces embeddings (LLM wiki, link-ranked retrieval) and "lint for orphans". **Frontmatter** supports database views (Bases, Dataview/Datacore), scheduling metadata and agent state such as confidence and status. **Paths** support the separation of raw from compiled content (`raw/` vs `wiki/`) and permission scoping. **App API (CLI/URI)** supports access to things that exist only at runtime: the resolved link graph, Bases query results, plugin functions, Publish and Sync.
- The design tension is that the files layer needs no app and is durable, while the CLI layer is richer but requires a running desktop app. That makes it awkward for headless servers and cron jobs (see Q5).

### Gaps
- I couldn't confirm whether the CLI can run fully headless, for example on a Linux server without a display. The docs only say the app must be running.

## Q2. The vault as agent workspace and memory (Claude Code, Codex, MCP memory servers, the LLM wiki)

### Takeaway
This is the most mature and highest-leverage upgrade in 2026, and it already works as a daily driver. Coding agents run directly in the vault folder, using a CLAUDE.md or AGENTS.md as the operating schema and Steph Ango's official obsidian-skills as format knowledge. Karpathy's April 2026 "LLM wiki" made the "compile raw sources into an interlinked wiki" pattern canonical. Its known ceiling is roughly 100–200 sources, or around 100K tokens of wiki, before quality degrades.

### Cited Findings
- **kepano/obsidian-skills** is MIT-licensed and holds six Agent Skills: obsidian-markdown (wikilinks, embeds, callouts, properties), obsidian-bases (`.base` views, filters, formulas), json-canvas, obsidian-cli, defuddle (clean web-to-Markdown extraction), and knap (rendering Markdown templates from JSON or CSV). It has about 50.6k stars and works with Claude Code, Codex, OpenCode and any agent that follows the Agent Skills spec. — [GitHub kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)
  - Star counts in press coverage range from 16k in March 2026 to 21.8k and 27k at other dates, which shows fast growth. — [aiforautomation.io](https://aiforautomation.io/news/2026-03-24-obsidian-ceo-agent-skills-ai-manage-notes-16k-stars); [Medium](https://medium.com/@hamzakhaledlklk/obsidians-ceo-just-taught-ai-how-to-use-his-own-app-here-s-the-0-way-to-do-it-too-97acbe8cfefe)
- **Karpathy's LLM wiki.** He posted on X in early April 2026, then followed with a gist. Raw articles, papers, repos and datasets go into `raw/`, captured via Obsidian Web Clipper. An LLM incrementally "compiles" a wiki, and Karpathy does not edit it by hand. Outputs are Markdown, Marp slides or matplotlib images, and he files them back into the wiki. One topic reached about 100 articles. — [DeepakNess summary](https://deepakness.com/raw/llm-knowledge-bases/); [X post](https://x.com/karpathy/status/2039805659525644595)
- **Gist structure.** Three layers: `raw/` (immutable), `wiki/` (LLM-written) and `CLAUDE.md` (schema). Three operations: Ingest (one source can touch 10–15 pages), Query (answers cite `[[wiki-links]]`) and Lint (contradictions, orphans, stale claims). The wiki also keeps `index.md` and `log.md`. The gist reportedly passed 5,000 stars within days. Reported sweet spot: under about 100–200 sources or under 100K tokens, with users seeing degradation at 200K–300K tokens even with 1M-token context windows. Criticisms: the user loses the learning that comes from filing their own notes, repeated LLM rewriting risks model-collapse-style error compounding, and the system hits a complexity ceiling. — [Starmorph guide](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide); [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- Community implementations of the LLM wiki include llmwiki, Ar9av/obsidian-wiki, NicholasSpisak/second-brain, llm-wiki-compiler, CacheZero, wiki-skills, and "LLM Wiki v2" (rohitg00), which adds memory lifecycle and confidence scoring. There is also an Obsidian plugin, "Karpathy LLM Wiki", which extracts entities and concepts into pages, adds bidirectional links and ranks retrieval by links rather than embeddings. — [Starmorph](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide); [Obsidian plugin listing](https://community.obsidian.md/plugins/karpathywiki); [julianoczkowski guide](https://github.com/julianoczkowski/karpathy-llm-wiki)
- A widely repeated quote attributed to Karpathy: "Obsidian is the IDE; the LLM is the programmer; the wiki is the codebase." I did not verify it against the primary post. — [boorghani.com tip](https://rss.boorghani.com/?p=408643)
- Typical second-brain setups with Claude Code use a vault-root CLAUDE.md, slash commands such as /ingest, /query, /lint and /log, and separate `raw/` and `wiki/` folders. One measured caveat: "Your Markdown files hold the durable record… Claude doesn't learn your vault automatically." Packaged versions include eugeniughelbur/obsidian-second-brain and claude-obsidian. — [HowToGeek](https://www.howtogeek.com/claude-obsidian-the-cheat-code-for-building-a-second-brain/); [obsidian-second-brain CLAUDE.md](https://github.com/eugeniughelbur/obsidian-second-brain/blob/main/CLAUDE.md); [claude-blog.md](https://claude-blog.md/blog/claude-obsidian-second-brain)
- **MCP memory servers that write Markdown into a vault:**
  - Basic Memory: the Markdown files are the source of truth and the local search index is disposable. Its default folder is `~/basic-memory`, and a misconfigured path can let the agent write outside the vault. — [Sylvain Leroy, Aug 2026](https://sylvainleroy.com/2026/08/basic-memory-persistent-ai-memory-obsidian/); [top-mcps](https://top-mcps.com/mcp/basic-memory)
  - second-brain-mcp is a read-only stdio server with four tools; the agent writes nothing itself. — [GitHub](https://github.com/noesskeetit/second-brain-mcp)
  - MemoryChat has write and update tools, and the user corrects memories by editing them in Obsidian. — [GitHub](https://github.com/dhawal-ss/memorychat)
  - mem-vault stores memories in a vault and uses Qdrant for search. mlx-memo runs on Apple MLX. ObsidianSharedMemory provides cross-agent shared memory. — [mem-vault](https://github.com/jagoff/mem-vault); [mlx-memo](https://pypi.org/project/mlx-memo/0.8.0/); [ObsidianSharedMemory](https://github.com/nhyxb/ObsidianSharedMemory)
- Counterpoint from commentators: "the 'memory problem' in AI agents is fundamentally a retrieval problem", and flat Markdown is "a wiki, not a memory system." — [themenonlab obsidian-mind](https://themenonlab.blog/blog/obsidian-mind-persistent-memory-ai-coding-agents); [aident.ai](https://aident.ai/blog/second-brain-without-obsidian-plain-markdown)

### Inferences
- **Maturity:** a coding agent plus CLAUDE.md plus obsidian-skills is a daily driver. The cost is an agent subscription, with about $20–200/month typical for Claude or Codex plans (not verified here). Lock-in risk is low because everything stays as Markdown. The fragility is agent-driven over-writes and drift, which git or file history mitigates (covered by other researchers).
- **Three designs of "vault as memory"** are emerging: (a) agent-writes-freely (Basic Memory, MemoryChat), (b) human-curated and agent-read-only (second-brain-mcp), and (c) separated raw and compiled layers (LLM wiki). The third resolves the "AI slop pollutes my notes" problem by putting LLM output in a different folder from human writing.
- One vault exposed over MCP can serve as shared memory across Claude, Cursor, ChatGPT and others. That works today but is fragmented across dozens of small, unaudited servers.

### Gaps
- I did not fetch Letta/MemGPT's current Markdown-memory features, Claude's own memory-file feature, or Codex AGENTS.md conventions as primary sources. The other AI-workflow researcher likely covers these.
- Most MCP memory servers are small new projects, and their maintenance and security are unverified.

## Q3. Automated ingestion pipelines (everything you read, hear and say flowing into the vault)

### Takeaway
Ingestion is mature for reading (Web Clipper, Readwise) and meetings (Granola), and is becoming mature for screen lifelogging (Screenpipe "pipes" that write daily Markdown). Wearables are fragile: Meta bought Limitless in December 2025 and ended Pendant sales, which shows the vendor risk of ingestion that depends on hardware.

### Cited Findings
- Karpathy's pipeline uses Obsidian Web Clipper into `raw/`. — [DeepakNess](https://deepakness.com/raw/llm-knowledge-bases/)
- defuddle, part of the official obsidian-skills, extracts clean Markdown from web pages for agents. — [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)
- **Screenpipe:** a "pipe" is a scheduled AI agent defined in one Markdown file (`~/.screenpipe/pipes/{name}/pipe.md`) that holds a prompt and a schedule (interval, daily or cron). The sample journal pipe runs every 2 hours and writes `~/obsidian-vault/screenpipe/<date>.md`. "Obsidian Daily Summary" is listed as one of the most-installed pipes. — [Screenpipe docs: pipes](https://docs.screenpi.pe/pipes); [quickstart](https://docs.screenpi.pe/quickstart); [use case](https://screenpi.pe/resources/use-cases/obsidian-ai-notes)
- **Limitless:** Meta announced the acquisition on 5 Dec 2025 and ended Pendant sales. Existing customers get at least a year of support, and Rewind and other non-Pendant features are being sunset. — [CNBC](https://www.cnbc.com/2025/12/05/meta-limitless-ai-wearable.html); [mlq.ai](https://mlq.ai/news/meta-acquires-ai-wearables-startup-limitless-ending-sales-of-pendant-device/)
- **Granola into Obsidian:** several community plugins use Granola's official API or MCP to sync notes, summaries and transcripts (Granola Sync, Granola API Sync, Granola Notes Merger), and there are Claude skills such as glebis "Granola Meeting Importer". Earlier approaches reverse-engineered Granola's local cache. One source says the API needs a paid plan and that free-plan MCP access is limited to the last 30 days (single source, unverified). — [Granola Sync plugin](https://community.obsidian.md/plugins/granola-sync); [Granola API Sync](https://community.obsidian.md/plugins/granola-api-sync); [Joseph Thacker, May 2025](https://josephthacker.com/hacking/2025/05/08/reverse-engineering-granola-notes.html); [glebis skill](https://agent-skills.md/skills/glebis/claude-skills/granola)
- Readwise Official is a plugin in the Obsidian community directory that syncs highlights into the vault. — [community.obsidian.md listing](https://community.obsidian.md/plugins/granola-sync)

### Inferences
- The robust pattern is to ingest into `raw/` or an inbox untouched, then run a separate agent or scheduled pass that compiles, links and tags. The vault gets the provenance of a data lake and the readability of a wiki.
- Fragility ranking, from most to least robust: open file formats such as Web Clipper (most robust), then official APIs (Readwise, Granola, plan-gated), then reverse-engineered caches, then single-vendor hardware (Limitless shows how that can fail).
- Screenpipe pipes being defined in Markdown is a sign of convergence: the automation is itself a note.

### Gaps
- I did not research Zotero (the Zotero Integration plugin), podcast or YouTube transcription pipelines, email-to-vault, or browser-history ingestion with sources. Raw volume from lifelogging versus vault signal-to-noise is unaddressed.

## Q4. Computation inside notes and the vault as a queryable database (Bases, Dataview/Datacore, DuckDB, JSON Canvas, CLI/URI)

### Takeaway
Bases, the first-party feature that turns frontmatter into a database, matured through 2026 (an API, group-by, kanban view, reorderable filters) and is now the default structured-data layer. Datacore is the beta successor to Dataview. DuckDB plugins bring SQL into notes and freeze the results as Markdown so agents can read them without running anything. Taken together, frontmatter plus Bases plus CLI is narrowing the "structured objects" gap with Tana and Capacities.

### Cited Findings
- Bases changes in 2026: an initial Bases API (1.12.x), a search toolbar, drag-and-drop import and row context menus (1.12.4), a Group menu (about 1 Oct 2026), a kanban view (about 5 Oct 2026), and reorderable filters (1.15.0 EA). — [Obsidian 1.12 changelog](https://obsidian.md/changelog/2026-02-27-desktop-v1.12.4/); [Releasebot](https://releasebot.io/updates/obsidian); [1.15.0 EA](https://obsidian.md/changelog/2026-10-22-desktop-v1.15.0/)
- The CLI has `bases` and `base:query` commands, so agents can query Bases headlessly while the app runs. — [Obsidian CLI help](https://obsidian.md/help/cli)
- Datacore is a "work-in-progress successor to Dataview" focused on UX and speed. It is in beta and installed via BRAT. Dataview's original author last committed in June 2024, but Dataview is still widely used and serves as a companion to Bases. — [Datacore via gittrend](https://gittrend.io/repo/blacksmithgu/datacore); [dsebastien Dataview guide](https://www.dsebastien.net/the-complete-guide-to-dataview-in-obsidian/)
- **DuckDB & MotherDuck plugin (about May 2026):** runs SQL in notes locally via DuckDB-WASM or against MotherDuck cloud, freezes results as Markdown tables, and stores the refresh schedule (daily or weekly) in frontmatter. It works on mobile. Agents read the cached results inline with no query or MCP round-trip, and trigger refreshes via the Obsidian CLI (`refreshFile`, `runQuery`). Staff had not reviewed it at listing time. — [MotherDuck blog](https://motherduck.com/blog/obsidian-vault-duckdb-ai-agents/); [plugin listing](https://www.obsidianstats.com/plugins/duckdb-motherduck)
- DuckData (DuckDB-WASM) runs SQL over inline CSV, Markdown tables and vault files and renders tables or charts. I found no plugin that does DuckDB SQL directly over frontmatter. — [DuckData](https://community.obsidian.md/plugins/duckdata)
- JSON Canvas is one of the six official agent skills, so agents can generate and edit `.canvas` files (nodes, edges, groups), and 1.12 counts Canvas links in the graph. — [obsidian-skills](https://github.com/kepano/obsidian-skills); [1.12 changelog](https://obsidian.md/changelog/2026-02-27-desktop-v1.12.4/)
- Maggie Appleton's "Programmable Notes" anticipates agent-based note systems that prompt and run custom workflows. — [maggieappleton.com](https://maggieappleton.com/programmatic-notes)

### Inferences
- The "freeze results into Markdown" pattern matters for agents: computation produces text, so any LLM can read it, and the next agent pass can diff it.
- JSON Canvas as a spatial reasoning surface (agents laying out argument maps, research boards or plan graphs) is technically supported today, but I found no strong evidence of daily-driver use. Treat it as promising.
- Compared with Tana's supertags and Capacities' typed objects: Bases views over typed frontmatter plus templates approximate "object types", but there is still no enforced schema or inheritance. That remains a gap (unverified against current Tana and Capacities features).

### Gaps
- I did not verify current executable code-block plugins (Execute Code), Jupyter integrations, or the Bases formula API in depth. I also did not check Tana, Capacities or Logseq DB-version feature sets for 2026.

## Q5. Scheduled and background automation (nightly digests, linting, resurfacing, CI on a vault repo)

### Takeaway
Scheduled agent passes over the vault are feasible today and appear in several 2026 tools: LLM-wiki "lint", Screenpipe cron pipes, and DuckDB refresh schedules held in frontmatter. Most of it is still DIY glue (cron, launchd, agent CLIs). "Contradiction detection" and "what changed in my thinking" reports exist as lint prompts, not as polished products.

### Cited Findings
- The LLM-wiki Lint operation checks for contradictions, orphan pages, missing concepts and stale claims, and `log.md` keeps an append-only record of ingests and contradictions found. — [Starmorph](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide)
- Screenpipe pipes support interval, daily and cron schedules and write into the vault. — [Screenpipe docs](https://docs.screenpi.pe/pipes)
- DuckDB plugin refresh cadence is set by a frontmatter property (`duckdb-motherduck-refresh: daily | weekly`). — [MotherDuck blog](https://motherduck.com/blog/obsidian-vault-duckdb-ai-agents/)
- The CLI's `orphans`, `unresolved` and `backlinks` commands give scheduled jobs graph-hygiene signals directly. — [Obsidian CLI help](https://obsidian.md/help/cli)
- "LLM Wiki v2" extends the pattern with memory lifecycle and confidence scoring, i.e. decay and resurfacing. — [Starmorph](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide)

### Inferences
- Architecture choice: file-only jobs (an agent CLI against the folder, or GitHub Actions on a git-backed vault) run headless. Jobs that need the CLI require a desktop session because the app must be running, so they suit an always-on Mac mini more than a Linux runner.
- "Semantic diffs of belief change" could be built today by having a nightly agent compare the `log.md` or git diffs with prior claims. I found no dedicated tool.

### Gaps
- I found no sourced 2025–2026 project dedicated to GitHub Actions on vaults, spaced resurfacing (for example a Spaced Repetition plugin or an Anki bridge), or automatic link suggestion. These were not searched for lack of budget.

## Q6. Publishing and feedback loops (Publish, Quartz, digital gardens)

### Takeaway
Publishing is a mature daily-driver category. Obsidian Publish is paid and first-party; Quartz is the leading open-source option. Quartz v5 adds a plugin pipeline, private pages and Bases-style views on the web, and Quartz Syncer offers diff-before-publish from inside Obsidian. The CLI's `publish:add` means agents can drive publishing too.

### Cited Findings
- Quartz v5 docs describe a plugin pipeline (transformers, filters, emitters; Preact, Lightning CSS), private pages, and "Bases"-style table, card and gallery views. The Quartz Syncer plugin does selective publish and remove via git with a diff viewer, and a `draft:` frontmatter flag controls visibility. I could not confirm an official v5 release announcement. — [Quartz docs mirror](https://docsearch.algolia.com/mcp/docs/repo/jackyzha0/quartz); [aiindigo 2026](https://aiindigo.com/blog/building-your-digital-garden-a-deep-dive-into-quartz-in-2026); [notes-automate](https://notes-automate.pages.dev/posts/how-to-publish-obsidian-notes-to-a-blog/)
- Obsidian Publish is described as an "excellent product but limited customization". — [notes-automate](https://notes-automate.pages.dev/posts/how-to-publish-obsidian-notes-to-a-blog/)
- The Obsidian CLI exposes Publish commands (`publish:add`, among others). — [Obsidian CLI help](https://obsidian.md/help/cli)
- Karpathy files generated outputs (Marp slides, plots) back into the wiki, closing the loop. — [DeepakNess](https://deepakness.com/raw/llm-knowledge-bases/)
- Maggie Appleton's writing popularised digital gardens and evergreen notes. — [self.md profile](https://self.md/people/maggie-appleton-digital-garden/)

### Inferences
- The frontier move is agent-assisted publishing: an agent proposes which notes are ready (by frontmatter status), drafts TILs or newsletter issues from the week's log, and opens a PR on the Quartz repo for human review. All of these parts exist; no single packaged product does it.

### Gaps
- I did not research vault-to-newsletter or vault-to-paper (Pandoc/LaTeX) pipelines, or audience feedback flowing back in (comments, webmentions).

## Q7. Multiplayer, local-first, and cross-tool bridges

### Takeaway
Real-time multiplayer works today through third-party Yjs/CRDT plugins, chiefly Relay by System 3. Obsidian Sync itself is not CRDT-aware, and mixing the two is risky. Ink & Switch's local-first and malleable-software research is the conceptual frame. Their Patchwork prototype explores version control for any document, which is where vaults could head.

### Cited Findings
- Relay (System 3) uses Yjs CRDTs for local-first real-time and async collaboration on chosen folders, and works offline. The collaboration server can be self-hosted but the auth server is closed source. A Starter tier costs $6 per user per month (forum details may be stale). — [GitHub Relay](https://github.com/No-Instructions/Relay); [Obsidian forum](https://forum.obsidian.md/t/relay-multiplayer-plugin-for-obsidian-collaborative-editing-and-folder-sharing/87170); [plugin listing](https://community.obsidian.md/plugins/system3-relay)
- Alternatives:
  - EVC Team Relay offers per-folder ACLs, self-hosting or managed service, and AI-agent access via MCP. It is not in the community catalogue.
  - Obsidian Live Share adds E2E encryption and presence.
  - obsidian-collab warns: "Collab is CRDT-aware; Obsidian Sync is not, and they don't coordinate."
  - LAN Vault Sync uses peer-to-peer Yjs with no server.
  
  — [EVC Team Relay](https://github.com/entire-vc/evc-team-relay-plugin); [Live Share](https://github.com/mewski/obsidian-live-share); [obsidian-collab](https://github.com/chikn8/obsidian-collab); [LAN Vault Sync](https://github.com/senjanson/lan-vault-sync)
- Ink & Switch, "Malleable Software: Restoring user agency in a world of locked-down apps" (June 2025; Litt, Horowitz, van Hardenberg). It argues that AI code generation alone does not deliver malleability and that environments must supply platform capabilities. Prototypes: Patchwork (version control across document types, used to write the essay), Potluck and Embark. — [Simon Willison summary](https://simonwillison.net/2025/Jun/11/malleable-software); [bmann notes](https://bmannconsulting.com/notes/malleable-software-essay/)

### Inferences
- Multiplayer vaults that include agents as participants, such as EVC Team Relay's MCP access, are an early frontier. Humans and agents would co-edit a CRDT-backed vault with per-folder permissions. Maturity: prototype to early daily-driver. Lock-in: moderate (closed auth server, relay service).
- Obsidian already serves as the "malleable" end-user environment (plugins, CSS, Bases) that the Ink & Switch essay describes. Agent Skills and the CLI lower the user-to-creator gradient further, because users can have agents write plugins via `plugin:reload` and `dev:*`.

### Gaps
- I did not research Todoist, Things, calendar or Anki bridges, Zotero, or Excalidraw with sources. I also did not research whether Obsidian has first-party multiplayer on its roadmap.

## Q8. Speculative frontier: personal fine-tunes, digital twins, tutors, belief diffs

### Takeaway
The speculative items remain mostly speculative. I found no Obsidian-specific, maintained pipeline that fine-tunes a personal LoRA on a vault. The practitioner consensus is that LoRA captures voice and style but not facts, so the plausible architecture is the vault for facts (wiki or retrieval) plus a small style adapter. Digital-twin tools that exist, such as WeClone, train on chat logs, not notes.

### Cited Findings
- LoRA suits "behavioral and task adaptation rather than adding large amounts of new factual knowledge", and data quality beats data size. — [Centron LoRA tutorial](https://www.centron.de/en/tutorial/lora-fine-tuning-for-llms-with-custom-data/)
- One practitioner who trained on 75k of their own messages warns that an unsanitized model will reproduce friends' names, addresses and card digits. On a 3B model, rank 8 underfit and rank 16 worked. — [dev.to, niclydon](https://dev.to/niclydon/i-trained-an-llm-on-75k-of-my-own-messages-so-it-would-stop-writing-like-a-chatbot-1dpi)
- WeClone builds digital twins via LoRA on personal chat history. — [openflows WeClone](https://openflows.pages.dev/currency/currents/weclone)
- Critics of the LLM wiki point to model-collapse-style compounding error from repeated LLM rewriting and to the loss of learning when filing is outsourced. Both are risks for any "twin" trained on LLM-compiled notes. — [Starmorph](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide)

### Inferences
- Rough maturity tiers:
  - **Works today:** an AI tutor or Q&A over your own notes (LLM wiki Query), multimodal notes (Marp, images, Canvas), agent-mediated belief-change logs (`log.md`).
  - **Prototype:** multiplayer human-plus-agent vaults, scheduled contradiction reports.
  - **Speculative:** personal LoRA or "digital twin" trained on the vault, semantic belief diffs as a product, a personal knowledge graph feeding continual fine-tuning.
- A caution for training on the vault: once the LLM wiki dominates the vault's content, a twin trained on it learns the LLM's prose more than the user's. Keep human-written notes and LLM-compiled notes in separate folders, as Karpathy's `raw/`/`wiki/` split already does, so training data stays clean.

### Gaps
- I found no primary-source 2026 project for a vault-to-LoRA pipeline or an Obsidian "digital twin". The evidence is anecdotal blogs.

## Q9. What frontier thinkers say

### Takeaway
Karpathy (LLM wiki: LLM as compiler, Obsidian as IDE), Steph Ango (files over apps, now encoded as official agent skills) and Ink & Switch (malleable, local-first software) are the active 2025–2026 voices with direct bearing on the topic. Matuschak and Appleton supply the older "tools for thought" frame. I found no 2025–2026 primary writing by Linus Lee or Simon Willison specifically on vaults.

### Cited Findings
- Karpathy: the LLM "compiles" raw material into a wiki he does not hand-edit. — [DeepakNess](https://deepakness.com/raw/llm-knowledge-bases/)
- Ango: files over apps. obsidian-skills teaches agents the native formats. — [dsebastien](https://www.dsebastien.net/obsidian-ai-skills-by-steph-ango/); [GitHub](https://github.com/kepano/obsidian-skills)
- Ink & Switch (Litt et al.): malleable software. AI alone isn't sufficient, and environments must provide platform capabilities. — [Simon Willison](https://simonwillison.net/2025/Jun/11/malleable-software)
- Matuschak: tools for thought as environments that "radically transform what people can think and do". His working notes include "A startling glimpse of malleable software" on AI-mediated software ecosystems. — [andymatuschak.org/sdac](https://andymatuschak.org/sdac/); [Antoine Buteau summary](https://www.antoinebuteau.com/lessons-from-andy-matuschak/)
- Appleton: tools for thought as cultural practices, not computational objects. "Programmable Notes" covers agentic note workflows. — [Tools for Thought essay](https://maggieappleton.com/tools-for-thought); [Programmable Notes](https://maggieappleton.com/programmatic-notes)

### Inferences
- There is an emerging consensus that the durable asset is the plain-text corpus. Apps and models are replaceable processors over it. The live debate is how much of the writing to delegate: Karpathy delegates everything in the wiki layer, while critics and Appleton's cultural-practice framing stress the user's own thinking.

### Gaps
- No 2025–2026 primary sources were found for Linus Lee (thesephist), Simon Willison on vaults or agent memory, Geoffrey Litt's individual 2026 posts, or Matuschak's latest notes on AI. Checking those sites directly is recommended.

## Q10. The highest-leverage upgrades, ranked

### Takeaway
Ranked by leverage, accounting for maturity and lock-in:
1. A coding agent in the vault, with CLAUDE.md or AGENTS.md and obsidian-skills.
2. A `raw/` vs `wiki/` LLM-wiki split with ingest, query and lint.
3. Automated ingestion into `raw/` (Web Clipper, Readwise, Granola, Screenpipe).
4. Bases plus CLI as a structured, agent-queryable layer.
5. Scheduled lint and digest jobs.
6. Publishing via Quartz or Publish.
7. Multiplayer via Relay.
8. A personal LoRA or twin (speculative).

### Cited Findings
- Each item rests on findings cited in Q2–Q8, e.g. [obsidian-skills](https://github.com/kepano/obsidian-skills), [Karpathy gist summary](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide), [Obsidian CLI](https://obsidian.md/help/cli), [Screenpipe pipes](https://docs.screenpi.pe/pipes), [Relay](https://github.com/No-Instructions/Relay).

### Inferences
- **Lowest lock-in, highest leverage:** items 1, 2 and 4, because everything stays as Markdown and YAML.
- **Highest fragility:** reverse-engineered ingestion, hardware wearables (Limitless), closed relay auth, and unreviewed plugins such as early DuckDB plugin listings.
- **Most important failure mode:** LLM-written content crowding out human thinking. Mitigate it with folder separation, provenance frontmatter (`source:`, `generated_by:`) and lint.

### Gaps
- Costs are not systematically sourced. Agent subscription pricing, Obsidian Sync and Publish pricing, and Screenpipe pricing were not verified in this pass.
