# Obsidian Tooling & AI/LLM Integrations for a Compounding Knowledge Base (as of Nov 2026)

Research note: about 20 tool calls. Primary sources were the Obsidian changelog, Obsidian help docs, and GitHub repo pages for Dataview, Smart Connections, Copilot, and kepano/obsidian-skills. Secondary sources were VentureBeat, forum threads, and blogs. Download counts and per-plugin last-commit dates for most community plugins were **not** verified this session; see the Gaps sections. Statements marked "(unverified this session)" come from the researcher's prior knowledge. Confirm them before stating them as fact.

## 1. Core plugins & recent releases (2025–2026)

### Takeaway
Obsidian's core has absorbed much of what used to need community plugins. **Bases** (May 2025; GA Aug 2025) covers database and table views of Properties, and gained kanban and grouping in late 2026. An **official CLI** (Feb 2026) and URI/CLI append-under-heading commands (Oct 2026) make the vault scriptable for agents. **Web Clipper** is the official capture path. The current version line is 1.14.x / 1.15 (Sep–Nov 2026).

### Cited Findings
**Release timeline:**
- **Bases** debuted in Obsidian 1.9.0 (May 2025) as Early Access, needing a Catalyst license. It was described as early beta, with more view types, plugin API access, and Publish integration planned. — [AlternativeTo](https://alternativeto.net/news/2025/5/obsidian-1-9-0-introduces-bases-plugin-for-database-style-note-management); [Neowin 1.9.0](https://www.neowin.net/news/obsidian-190-launches-with-new-file-format-footnotes-view-plugin-and-more/)
- Bases became available to all users in 1.9.10. An Android build listing dates it to about August 19, 2025. — [Neowin 1.9.10](https://www.neowin.net/news/obsidian-1910-lands-with-a-new-core-plugin-bug-fixes-and-more/)
- With 1.9, Obsidian dropped the singular property keys `tag`, `alias`, and `cssclass`. Users must switch to the plural `tags`, `aliases`, and `cssclasses`, formatted as lists. This is a maintenance item for older vaults. — [Neowin 1.9.0](https://www.neowin.net/news/obsidian-190-launches-with-new-file-format-footnotes-view-plugin-and-more/)
- **Obsidian CLI** shipped in desktop **v1.12.4 (Feb 27, 2026)**, described as "a command line interface that lets you control Obsidian from your terminal for scripting, automation, and integration with external tools". The same release added image resizing and automatic attachment cleanup. — [Obsidian changelog 1.12.4](https://obsidian.md/changelog/2026-02-27-desktop-v1.12.4/)
- **v1.12.7 (Mar 23, 2026):** the installer now bundles a dedicated CLI binary, which is faster than calling Electron. It also adds autocompletion and moves the CLI socket to a hidden dotfile. A new installer is required. — [Obsidian changelog 1.12.7](https://obsidian.md/changelog/2026-03-23-desktop-v1.12.7/)
- **v1.14.0 (Sep 2, 2026):** color highlights, a Bases **kanban** layout, and a right-to-left workspace. **1.14.1 (Sep 8):** MathJax 4.1.3 and Bases RTL tables. **1.14.2 (Sep 15):** open Markdown files from outside the vault (desktop only), and base font size per device. **1.14.3 (Sep 29):** macOS Quick Look previews and a Bases Group menu. **1.14.4 (Oct 1):** Bases "Hide column" for kanban, search that matches full file paths, and a fix for a **metadata cache memory leak**. **1.14.5 (Oct 22):** Electron security update; reinstall required. — [Obsidian changelog](https://obsidian.md/changelog/)
- **v1.15 (Oct 22 / Nov 2, 2026):** Mermaid rendered via a new library, reorderable Bases filters, **URI/CLI commands to append or prepend under a heading**, and faster community plugin loading. — [Obsidian changelog](https://obsidian.md/changelog/)

**Web Clipper (official, free, open source):**
- Features include per-site templates (variables, filters, conditionals and loops), a **Highlighter**, a **Reader** view, and an **Interpreter** that uses natural-language prompts to extract or modify page data.
- It runs on Chromium browsers, Firefox, Edge, and Safari, including iOS/iPadOS Safari and Firefox Mobile.
- It saves locally to the vault and collects no usage data.
- Source: [Obsidian Help – Web Clipper](https://obsidian.md/help/web-clipper)

### Inferences
- For a compounding knowledge base, the core plugins that matter most are:
  - **Properties + Bases:** structured retrieval and maintenance dashboards.
  - **Backlinks / Outgoing links**, including unlinked mentions.
  - **Daily notes + Templates:** low-friction capture.
  - **Web Clipper:** capture.
  - **File recovery:** local snapshots. Its behavior was not verified this session.
  - **Sync**, if paying.
- **Canvas** is useful for thinking sessions but is not central to compounding.
- The **CLI** plus the append-under-heading commands are the significant new infrastructure for agent workflows. They let Claude Code and similar agents act through Obsidian's own index instead of raw file edits.
- Bases' rapid iteration (kanban, grouping, reorderable filters within ~2 months in late 2026) shows the core team is investing there. That makes Bases the safer long-term bet over Dataview for property-based views.

### Gaps
- The exact desktop release date of 1.9.10 (the Android listing date was used as a proxy).
- Whether a Bases plugin API and Publish support have shipped by Nov 2026 was not verified.
- What exactly changed in Properties, Unique note creator, Canvas, and Sync during 2025–2026 was not verified. The changelog fetch covered only Sep–Nov 2026.
- Calendar view for Bases: the status is unknown.

## 2. Community plugins: durable vs. risky/redundant

### Takeaway
**Dataview vs. Bases is the main decision.** Bases is easier to learn and is the core-supported path for property queries. Dataview remains more expressive: DQL, DataviewJS, and inline fields. Dataview is not dead; it got a new maintainer and releases in spring 2026. Still, for a long-lived vault, new structured views should go in Bases and Dataview should be kept only for queries Bases can't express.

### Cited Findings
**Dataview maintenance status:**
- Release 0.5.68 (15 March) was the first by new maintainer **holroy**, and 0.5.70 (7 April) is the latest, tagged "Beta". The page doesn't show the year. Given the "dataview-to-bases" claim below, the most likely year is 2026, but this is unconfirmed. — [Dataview releases](https://github.com/blacksmithgu/obsidian-dataview/releases)
- **Conflict:** the "Dataview to Bases" migration plugin describes Dataview as having had no release in over a year. Its listing may predate the holroy releases. — [Dataview to Bases plugin](https://community.obsidian.md/plugins/dataview-to-bases)
- The migration plugin notes a semantic difference: Dataview applies LIMIT where it is written, while Bases always filters, then sorts, then limits. — [Dataview to Bases plugin](https://community.obsidian.md/plugins/dataview-to-bases)

**Bases vs. Dataview capability:**
- Forum commenters describe Bases as an alternative for specific use cases rather than a full replacement. It is easier to learn, and it can do some things Dataview can't. — [Obsidian forum – Databases core plugin thread](https://forum.obsidian.md/t/obsidian-databases-core-plugin/66182)
- I found no 2026 source declaring Dataview officially deprecated. — (search result synthesis; same thread)

**Plugin reliability and performance:**
- Plugins run as code on top of a single-threaded UI, so a slow plugin callback can delay typing.
- Tools exist to profile plugin load times: FlowKit Health Dashboard and Startup Metrics Logger.
- Sources: [Obsidian forum – slow typing](https://forum.obsidian.md/t/slow-typing-to-mars-and-back/66543); [Startup Metrics Logger](https://community.obsidian.md/plugins/startup-metrics-logger); [FlowKit Health Dashboard](https://community.obsidian.md/plugins/flowkit-health-dashboard)

### Inferences
**Practitioner consensus (unverified this session):** the following are long-lived and widely recommended. Each needs a last-commit check before citing.
- **Templater:** dynamic templates.
- **QuickAdd:** capture macros. It overlaps with the new CLI/URI append commands.
- **Periodic Notes:** weekly, monthly, and quarterly notes. It has historically had long maintenance gaps; check status.
- **Omnisearch:** BM25 full-text search with OCR and PDF support. It is partly superseded by improved core search (1.14.4 path matching) and by semantic search plugins.
- **Spaced Repetition** (st3v3nmw).
- **Linter.**
- **Obsidian Git.**
- **Strange New Worlds:** inline link counts that aid resurfacing.
- **Zotero Integration**, or **Citations**.
- **Readwise Official.**

**Redundancy now that Bases and newer core features exist:**
- Dataview for simple property tables, which Bases now covers.
- "DB Folder" / Projects-style database plugins. Bases covers these, and **Projects** (marcusolsson) was reportedly archived (unverified).
- Kanban for property-driven boards. Bases kanban arrived in 1.14.0. The Markdown-file-based Kanban plugin still serves a different use.
- Plugins for opening external Markdown files, now native in 1.14.2.
- Some QuickAdd "append to section" use cases, now covered by the 1.15 CLI/URI commands.

**Fragility heuristic:** prefer plugins whose output is plain Markdown/YAML that stays readable if the plugin dies. Templater output, Linter fixes, and Bases `.base` files are all plain text. Be wary of plugins that store meaning in proprietary syntax rendered only at runtime: DataviewJS blocks, inline `key:: value` fields that Bases doesn't read, and plugin-specific code blocks. This matters most for compounding, because these break silently years later.

### Gaps
- Download counts and last-commit dates from obsidian.md/plugins or obsidianstats.com were not collected for Templater, QuickAdd, Periodic Notes, Omnisearch, Spaced Repetition, Linter, Obsidian Git, Strange New Worlds, Zotero Integration, or Readwise. I could not confirm which are abandoned as of Nov 2026.
- Whether Bases reads Dataview inline fields was not verified. The working assumption is no, since Bases is built on Properties/YAML.

## 3. Capture pipelines

### Takeaway
The durable capture stack is:
- **Web Clipper** for the web, with templates that map to Properties.
- **Readwise** for highlights from Kindle, articles, and podcasts.
- **Zotero** for academic sources.
- **Daily note / QuickAdd / CLI append** for quick thoughts.

Karpathy's LLM-wiki pattern also uses Web Clipper as its intake, which reinforces it as the standard.

### Cited Findings
- Web Clipper templates, Highlighter, and Interpreter (natural-language extraction) run on desktop browsers and on iOS Safari and Firefox Mobile. Content is saved locally. — [Obsidian Help – Web Clipper](https://obsidian.md/help/web-clipper)
- Karpathy's LLM knowledge base uses Obsidian Web Clipper to convert web content into Markdown in a `raw/` folder. Images are stored locally so a vision LLM can view them. — [VentureBeat, Apr 3 2026](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an)
- The 1.15 release added URI/CLI commands to append or prepend content under a specific heading. This is a native, scriptable quick-capture target, e.g. from iOS Shortcuts or an agent. — [Obsidian changelog](https://obsidian.md/changelog/)
- kepano's agent skills include **defuddle**, which extracts clean Markdown from web pages to reduce tokens. It is the same extraction approach Web Clipper uses. — [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)

### Inferences
- Treat clipped and imported material as **source notes** (raw input) kept separate from your own synthesized notes. This mirrors Karpathy's raw/ vs. wiki/ split and protects the generation effect; see section 5.
- The Web Clipper **Interpreter** can pre-fill summary properties with an LLM at capture time. That is convenient, but it puts AI-written text into notes. Keep it in clearly labeled properties or callouts.

### Gaps
- Current status of the Readwise Official plugin and Zotero Integration plugin (maintenance, 2026 changes) was not verified.
- Mobile quick-capture options were not researched in depth: iOS Shortcuts + URI, the Android share sheet, and third-party apps such as Drafts.

## 4. Resurfacing and review mechanisms

### Takeaway
Little primary-source evidence was gathered. The available signal is this:
- Obsidian's own **Smart Connections**-style semantic "related notes", Strange New Worlds link counts, and Bases views over properties like `last_reviewed` or `status` are the main ways to bring old notes back.
- A "random connection" command in Smart Connections offers serendipitous resurfacing.
- Critics argue most second-brain notes are "write-only" and never revisited.

### Cited Findings
- Smart Connections offers a Connections view that shows semantically related notes, with similarity scores, while you write. You can drag a result in to create a link. It also has a **random-connection command** that jumps to a strongly connected note. — [Smart Connections GitHub](https://github.com/brianpetro/obsidian-smart-connections)
- The "write-only second brain" critique holds that most notes never get revisited. — [ToolsForHumans blog](https://www.toolsforhumans.ai/blog/your-second-brain-is-write-only-heres-why-most-notes-never-get-revisited)
- Another critique: "a PKM that only accumulates isn't a second brain. It's a second inbox." The argument is that value comes from discarding and reframing. — (search snippet; source among [Second brains aren't really second brains](https://blog-v1-49p.pages.dev/blog/post5/scourge-of-pkms))

### Inferences
- The tooling for resurfacing has three layers:
  1. **Passive context surfacing** while writing: Smart Connections' related notes, the backlinks pane, and Strange New Worlds counts.
  2. **Scheduled review:** Periodic Notes weekly reviews, plus a Bases view filtered on `reviewed < 90 days ago`.
  3. **Spaced repetition**, for atomic facts only.
- Passive surfacing is the highest-leverage layer because it costs no extra habit. Bases makes layer 2 possible without Dataview.
- LLM agents can produce "what changed / what's stale / orphan notes" reports (Karpathy's "linting/health checks"). This is a new resurfacing channel; see section 5.

### Gaps
- No 2026 sources were gathered on the Spaced Repetition plugin's status or on Random Note core plugin usage.
- No empirical data was found on which resurfacing mechanisms practitioners keep using long term.

## 5. AI/LLM integration: what helps vs. hurts compounding

### Takeaway
By 2026 there are three integration patterns:
1. **In-app plugins:** Smart Connections for local-embedding semantic links and search; Copilot for chat, now with agent mode embedding Claude Code/OpenCode/Codex.
2. **External agents** (Claude Code, Codex) working directly on the vault folder. They are helped by kepano's **obsidian-skills** (~50k stars) and the official **CLI**.
3. **MCP servers**, either the generic filesystem MCP or Local-REST-API-based Obsidian MCPs.

Karpathy's April 2026 "LLM Knowledge Bases" post made LLM-maintained wikis mainstream. A visible counter-movement ("Keep AI Out of Your Obsidian Vault," Aug 2026) argues AI-written notes and links destroy the thinking that makes a vault valuable.

**Emerging best practice:** keep a human-authored core and an AI-maintained layer separate. Use AI for retrieval, link suggestions, maintenance and linting, and source summaries. Do not use it for your own syntheses.

### Cited Findings

**Karpathy "LLM Knowledge Bases" / LLM wiki:**
- Posted on X, around early April 2026: [x.com/karpathy/status/2039805659525644595](https://x.com/karpathy/status/2039805659525644595). Raw sources such as papers, repos, datasets, and articles go into `raw/`. The LLM "compiles" a wiki of summaries, concept articles, and backlinks, and navigates it through index and summary files rather than a vector DB.
- The LLM runs "linting/health checks" for inconsistencies, missing data, and new connections. Quote: "You rarely ever write or edit the wiki manually; it's the domain of the LLM."
- Scale: about 100 articles and about 400k words, navigable without RAG. Even the article itself calls the setup a "hacky collection of scripts."
- Source: [VentureBeat, Apr 3 2026](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an)
- Karpathy frames it as "Obsidian is the IDE, the LLM is the programmer, the wiki is the codebase." Answers to queries are filed back into the wiki so it compounds. — secondary: [MindStudio](https://www.mindstudio.ai/blog/andrej-karpathy-llm-wiki-obsidian-ai-second-brain); [Implicator (reports ~16M views)](https://implicator.ai/karpathys-llm-wiki-got-16-million-views-the-code-isnt-the-point-2/)
- Community implementations include a "Karpathy LLM Wiki" Obsidian plugin and "karpathy-kb" agent skills. — [obsidianstats](https://www.obsidianstats.com/plugins/karpathywiki); [skills.sh](https://www.skills.sh/pedronauck/skills/karpathy-kb)

**kepano/obsidian-skills** (from Obsidian CEO Steph Ango's GitHub account; MIT; ~50.6k stars):
- Agent Skills for obsidian-markdown (wikilinks, embeds, callouts, properties), obsidian-bases, json-canvas, obsidian-cli, defuddle, and knap.
- For Claude Code, the repo is installed into `.claude` at the vault root. The repo gives no guidance on how agents should behave when editing.
- Source: [GitHub kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)

**MCP servers:**
- **Option 1, generic filesystem MCP:** Anthropic's filesystem MCP can point straight at the vault folder. It is simplest but has no Obsidian-specific features.
- **Option 2, Obsidian-specific MCP servers:** these mostly need the **Local REST API** community plugin. The richer ones include cyanheads' obsidian-mcp-server (~14 tools, section-aware PATCH, tag and frontmatter management).
- Guides warn of full read/write access and recommend a git backup first.
- Sources: [ContextBolt guide](https://contextbolt.com/blog/obsidian-mcp-claude/); [Playbooks](https://playbooks.com/mcp/stevenstavrakis-obsidian); [PyPI obsidian-mcp-server](https://pypi.org/project/obsidian-mcp-server)

**Smart Connections (Brian Petro):**
- Version 4 has about 5.5k stars and ships a built-in local embedding model ("just works"). It needs no API key, works offline and on mobile, and offers a Connections view and Lookup semantic search.
- Smart Chat was split into a separate plugin, and API model integrations moved to Smart Chat Pro.
- The license is now **source-available "Smart Plugins License"**, which restricts competing offerings. Earlier versions were GPL; the switch reportedly happened in early 2026.
- "Pro" features (inline/footer connections, ranking, Bases integration) are for supporters.
- The embedding model is not named.
- Sources: [GitHub](https://github.com/brianpetro/obsidian-smart-connections); license-change timing per [PromptQuorum review](https://www.promptquorum.com/power-local-llm/smart-connections-review) (only one source)

**Copilot for Obsidian (Logan Yang / Brevilabs):**
- "Copilot V4" (~7.9k stars, AGPL-3.0 frontend, closed backend). It has an **Agent mode that runs OpenCode, Claude Code, or Codex inside Obsidian** with user-controlled permissions, plus Projects, Skills, Commands, and Quick Ask. Agent mode is desktop-only.
- Free with BYOK or local models. Hosted models and multi-agent features require Copilot Plus.
- API keys are stored in the Obsidian Keychain rather than `data.json`. Free OpenCode Zen models may log or train on prompts.
- Sources: [GitHub logancyang/obsidian-copilot](https://github.com/logancyang/obsidian-copilot). A third-party comparison lists Plus at $14.99/mo, unverified: [Anthem Creation](https://anthemcreation.com/en/artificial-intelligence/ai-plugins-obsidian-2026-comparison/)
- Reviewers describe Smart Connections as semantic search and link discovery, and Copilot as chat. Several recommend running both together. — [PromptQuorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026); [wetheflywheel radar](https://wetheflywheel.com/en/radar/obsidian-ai-plugins/)

**Critique: "Keep AI Out of Your Obsidian Vault"** (ssp.sh, on HN about Aug 2026):
- The author argues AI-generated notes and connections are a dead end: "AI summaries become noise, and you lose the thinking that comes from making your own links." Quote: "It's so hard to finish an idea that is not yours and is just suggested by AI." The author recommends AI for research and separate experiments, with the main vault kept human-curated.
- HN commenters made three points:
  - Agents write confident claims that later sessions treat as fact, a hallucination-compounding risk.
  - "Ownership can't be delegated": the AI resolves ambiguity arbitrarily.
  - One user keeps a **separate AI-managed vault** as a scratchpad.
- Sources: [ssp.sh](https://www.ssp.sh/brain/using-obsidian-with-ai/); [HN via Zeli](https://zeli.app/story/49450898)
- **Generation-effect argument:** self-generated information is remembered far better than consumed information, so an AI-written vault becomes "a library rather than a workshop."
  - Caveat: this is an extrapolation from the generation-effect literature. No study was found that tests AI-written notes specifically.
  - Proponents counter that AI removes PKM's main barrier, which is the cost of maintenance.
  - Sources: [rjroy LLM-PKM landscape](https://rjroy.github.io/ideas/llm-integrated-pkm/research/landscape-results); [rjroy critique](https://rjroy.github.io/ideas/llm-integrated-pkm/research/critique-results); [Habr](https://habr.com/ru/articles/1031112/)
- **Privacy:** data leaves the machine whenever Claude Code or cloud LLMs read the vault. Portuguese-language guide: [horadecodar](https://horadecodar.com.br/claude-code-obsidian-privacidade/). Local options: Smart Connections' local embeddings; Copilot with Ollama or LM Studio. — [Smart Connections GitHub](https://github.com/brianpetro/obsidian-smart-connections); [PromptQuorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026)

### Inferences
**Where AI helps compounding:**
1. **Retrieval and related-note surfacing** (semantic search, local embeddings). It is low-risk because nothing is written.
2. **Link *suggestions*** that a human accepts, e.g. drag-to-link in Smart Connections. A human-approved link preserves the thinking step.
3. **Maintenance and linting:** orphan detection, broken links, property normalization, duplicate detection, stale-note reports. Bases, the CLI, and agents like Claude Code are well suited.
4. **Source-note processing:** summarizing clipped and raw material into clearly labeled source notes.
5. **Q&A over the vault**, with answers filed back as clearly marked AI notes (Karpathy's flywheel).

**Where AI hurts:**
- AI-written "permanent" or "evergreen" notes in the user's voice remove the generation effect.
- Bulk auto-linking creates hallucinated or shallow links that pollute the graph and backlinks.
- Confident AI claims get re-ingested by later agent sessions as fact, a compounding-error loop.
- Silent bulk edits by MCP or agents with write access.
- Privacy leakage to cloud providers.

**Practical guardrails** synthesized from sources:
- Keep a human-written core separate from an AI layer (separate folder or vault, `author: ai` / `generated: true` properties).
- Use git before granting any agent write access.
- Prefer the official CLI or MCP tools that edit by section over whole-file rewrites.
- Use local embeddings for sensitive vaults.
- Use Karpathy's raw/ → wiki/ split, where raw is immutable.

**Choosing the agent path:**
- Claude Code + kepano/obsidian-skills + Obsidian CLI is now the most "native" agent path. It is backed by the Obsidian CEO's own repo and the official CLI.
- MCP servers are the path for Claude Desktop and other non-CLI clients. Local REST API-based MCPs add a dependency chain of plugin → server → client, which is more fragile than a plain filesystem MCP or Claude Code on files.

**Scale fit:** the LLM-wiki pattern without RAG fits ~100–10k high-signal documents, per VentureBeat's comparison table. A 10k+ personal vault likely needs embeddings or search (Smart Connections, Copilot's Miyo index, Omnisearch) in addition to index files.

### Gaps
- Karpathy's original gist (if one exists separately from the X post) was not read directly. The details come from VentureBeat plus secondary blogs.
- No first-party Anthropic docs were fetched this session on MCP connectors for Obsidian or on Claude Desktop's local-file access.
- No official Obsidian or kepano statement on AI-in-vault best practice was found. kepano's personal "vault" philosophy posts were not located.
- Smart Connections' embedding model name and the exact license-change date: only one source.
- Copilot Plus pricing was unverified on the official pricing page.
- No empirical study on AI-written notes vs. retention was found.

## 6. Sync, backup, and versioning

### Takeaway
**Obsidian Sync is the only officially supported sync.** iCloud is the most frequently reported source of data loss, especially on Windows and with offloading. Git provides versioning but is manual and awkward on mobile. Syncthing works best with an always-on device. The consistent practitioner rule is **sync ≠ backup**: run an independent backup (git, Time Machine, or similar) whatever the sync method. This matters doubly once AI agents have write access.

### Cited Findings
- **Obsidian Help** lists Obsidian Sync as the only official option.
- Community options: iCloud, OneDrive, Google Drive, Syncthing (Android via the community "Syncthing-Fork" because the official app is discontinued), Git, Working Copy (iOS), and Remotely Save / LiveSync plugins.
- **Warnings:**
  - iCloud on Windows "may lead to file duplication or corruption."
  - "Avoid syncing the same vault across multiple services."
  - Keep files downloaded; offloading makes files appear missing.
  - Git sync is manual push/pull.
  - Syncthing works best with an always-on device.
- Source: [Obsidian Help – Sync your notes](https://obsidian.md/help/sync-notes)
- Forum reports of **iCloud data loss** are numerous: silent overwrites, 0-byte files, deletion when iCloud ran out of space. — [iCloud data loss thread](https://forum.obsidian.md/t/icloud-data-loss-issue-sync-conflict-handling/113584); [silently overwritten](https://forum.obsidian.md/t/note-content-silently-overwritten-by-another-note-icloud-vault-no-remote-sync/98672); [iCloud out of space](https://forum.obsidian.md/t/icloud-ran-out-of-space-and-deleted-the-contents-of-my-active-file/24217)
- **Obsidian Sync** is not immune. There are reports of data loss and merge issues, but several users moved to it from iCloud for reliability. — [constant data loss thread](https://forum.obsidian.md/t/constant-data-loss-between-mobile-and-desktop/66663); [Obsidian Sync seems to delete files](https://forum.obsidian.md/t/obsidian-sync-seems-to-delete-files/11366)
- MCP setup guides recommend backing up the vault with git before granting agent write access. — [Playbooks](https://playbooks.com/mcp/stevenstavrakis-obsidian)

### Inferences
**Recommended durable stack:**
- Obsidian Sync, or Syncthing for technical users with an always-on node, for live multi-device sync.
- **Obsidian Git** (or a cron git commit) on one desktop for versioned history.
- An off-machine backup.

**Things to avoid:**
- Stacking iCloud with Obsidian Sync (multiple services).
- Windows + iCloud.

**Agent-specific:** git becomes non-negotiable when Claude Code or MCP agents edit the vault, because `git diff` is how you review AI edits. This also gives a provenance trail separating human from AI changes.

### Gaps
- No head-to-head reliability data (only anecdotes).
- Obsidian Sync 2025–2026 feature changes (version history length, selective sync, pricing) were not verified.
- No sources were gathered specifically on Git or Syncthing failure modes.

## 7. Performance at scale (10k+ notes)

### Takeaway
Core Obsidian generally handles ~10–20k notes. Reported slowdowns at that scale are usually tied to heavy plugin loads, large attachments, or CSS, not note count alone. At 40k+ some users report degradation. Recent releases fixed a metadata-cache memory leak (1.14.4) and sped up plugin loading (1.15).

### Cited Findings
**Forum reports (anecdotal):**
- 20k notes with 70 plugins → hanging; the user split the vault. — [Obsidian forum – Obsidian Hanging](https://forum.obsidian.md/t/obsidian-hanging/102330)
- 40k imported notes degraded performance, and reducing to 10k restored it. Restricted mode didn't help. — [Help! Obsidian Lags with Many Notes](https://forum.obsidian.md/t/help-obsidian-lags-with-many-notes/82241)
- 13k notes with ~60 plugins: no startup problem. — [Slow Obsidian Startup](https://forum.obsidian.md/t/slow-obsidian-startup/41480)

**Performance factors:**
- The single-threaded UI means one slow plugin callback can delay typing. — [Slow Typing thread](https://forum.obsidian.md/t/slow-typing-to-mars-and-back/66543)
- Profiling tools are available: Startup Metrics Logger and FlowKit Health Dashboard. — [Startup Metrics Logger](https://community.obsidian.md/plugins/startup-metrics-logger); [FlowKit](https://community.obsidian.md/plugins/flowkit-health-dashboard)
- 1.14.4 fixed a metadata cache memory leak, and 1.15 brought faster community plugin loading. — [Obsidian changelog](https://obsidian.md/changelog/)

### Inferences
- At 10k+ notes, the fragility comes from plugin count and plugin type, not Obsidian core.
- The likely heavy categories are whole-vault indexers: Dataview with many live queries, embedding plugins during initial indexing, Omnisearch with OCR, and graph-heavy plugins.
- Bases, being core, is likely more efficient than equivalent Dataview queries, but no benchmark was found.
- Agents working on files via the CLI or filesystem are unaffected by UI performance.

### Gaps
- No controlled benchmarks were found for Bases vs. Dataview, or for Smart Connections indexing time at 10k+ notes.
- No official Obsidian guidance on vault-size limits was found.
