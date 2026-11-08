# AI/LLM Workflows with an Obsidian Vault (as of November 2026)

Scope note: this covers workflows and usage. Embedding/vector infrastructure is covered elsewhere. Background already established (Karpathy LLM wiki, kepano/obsidian-skills, Obsidian CLI 1.12.4, Smart Connections v4, Copilot V4 agent mode, MCP via Local REST API, "keep AI out of your vault" critique) is not repeated except where new detail was found. Items marked "(snippet only)" come from search-result summaries I did not open; treat them as lower confidence.

## 1. Coding agents (Claude Code / Codex / others) run inside a vault: conventions, recipes, published examples

### Takeaway
The dominant 2026 pattern is simple: `cd` into the vault, run Claude Code, and put conventions in a vault-root CLAUDE.md, with workflows packaged as `.claude/skills/` or slash commands. The best published practitioners (Eleanor Konik, Kenneth Reitz, the Claudesidian kit) all lean on three habits: strict conventions such as frontmatter schemas and folder numbering, git after every change, and the agent proposing while the human decides. The most valuable recipes are read-heavy: pattern-finding, indexing, health checks, and cited synthesis. Bulk rewriting of human notes is not among them.

### Cited Findings
**Published practitioner examples**
- **Kenneth Reitz (Mar 6, 2026), setup.** He has 467 markdown files in an iCloud-synced folder, with numbered PARA-style sections (000 Meta to 900 Archive). He points Claude Code at the folder, and a ~200-line root CLAUDE.md gives it context. — [Kenneth Reitz, "Obsidian Vaults & Claude Code"](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code)
- **Reitz's CLAUDE.md.** Conventions: use wikilinks, require frontmatter on new notes, prefer tables for comparisons, link liberally. Prohibitions: don't create files unless asked, don't restructure folders, no emojis, don't over-engineer, don't editorialize about mental-health content. Frontmatter schema: `type`, `role`, `status`, `date`, `themes`. — [Reitz](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code)
- **Reitz's tasks.** These are cross-temporal pattern questions: themes in March daily notes that vanish by June, creative uncertainty compared with what actually shipped, week-over-week writing shifts. His recipe is to run a Dataview query first, then ask Claude to interpret the results. His principle is "Claude proposes, you dispose." He also says "The vault does not make me smarter. It makes me more honest." — [Reitz](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code)
- **Eleanor Konik (Jan 22, 2026), setup.** Konik is an Obsidian moderator with a vault of ~15M words. She runs Claude Code from the polyipseity Terminal plugin inside Obsidian, choosing it over the Claudian plugin because Claudian lacked plan mode. The vault sits inside a parent folder so the agent can `cd ..` into sibling code repos. — [Eleanor Konik, "Claude + Obsidian Got a Level Up"](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **Konik's conventions.** CLAUDE.md tells Claude to commit to git after every change. When she corrects Claude, she has it write the correction into the relevant skill file or CLAUDE.md, so the rules keep improving. She keeps a log of problems and corrections. Skills are written as modular "functions" that call each other. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **Konik's workflows.**
  - An overnight pass over the whole vault that produced an index file surfacing forgotten notes.
  - Migrating old notes to a new metadata schema through pull requests rather than direct edits.
  - Fixing encoding garbage left by an RSS plugin.
  - Building a Telegram bot plus Obsidian plugin for quick inbox capture.

  — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **Konik's pain points.** Large file changes made Obsidian's cache go stale, sometimes requiring a restart. Obsidian Sync struggled with frequent large folder changes. Earlier MCP-based attempts were "hit or miss." Her vault deliberately holds no private information. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **ContextBolt's account of Konik.** A third party describes her pattern as plain Filesystem MCP with the complexity kept in prompts and scripts: a "minimal stack for writers." — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/)

**Starter kits and skill packs (concrete recipes)**
- **Claudesidian** (heyitsnoah, ~2.6k stars, 193 forks, MIT):
  - Folders: PARA (`00_Inbox` … `06_Metadata`).
  - `/init-bootstrap` wizard: generates a personalized CLAUDE.md, imports an existing vault to `OLD_VAULT/` rather than merging, and sets up git.
  - Commands: `/thinking-partner` (questions, not answers), `/daily-review`, `/research-assistant`, `/upgrade`.
  - Auto-triggered skills: `inbox-processor`, `weekly-synthesis`, `pull-request`.
  - Explicit "thinking mode" vs "writing mode."
  - The upgrade process "never touches your content folders," makes a timestamped backup, and shows per-file diffs.

  — [GitHub heyitsnoah/claudesidian](https://github.com/heyitsnoah/claudesidian)
- **az9713/claude-code-obsidian** (small: 4 stars, but a clean recipe set). It bundles kepano's obsidian-markdown/bases/json-canvas/obsidian-cli/defuddle skills plus:
  - `/vault-journal`: logs to the daily note and wikilinks related projects.
  - `/vault-capture`: URL to defuddle to a structured note.
  - `/vault-synthesize`: searches the vault and writes a cited synthesis note.
  - `/vault-moc`: generates a categorized Map of Content.
  - `/vault-health`: unresolved links, orphans, and missing frontmatter, written up as a prioritized cleanup report.
  - `/vault-save`: saves an insight from the chat as a permanent note.

  — [GitHub az9713/claude-code-obsidian](https://github.com/az9713/claude-code-obsidian)
- **ballred/obsidian-claude-pkm** starter kit: ships `weekly`, `daily`, `review`, and `adopt` skills and a "weekly-reviewer" agent (reflection, goal alignment, planning). — [skills.sh listing](https://www.skills.sh/ballred/obsidian-claude-pkm/review); [vibeindex weekly](https://www.vibeindex.ai/skills/ballred/obsidian-claude-pkm/weekly) (snippet only)
- **obsidian-second-brain** (eugeniughelbur): advertises 43 commands that work across Claude Code, Codex, Gemini, and OpenCode. — [gittrend](https://gittrend.io/repo/eugeniughelbur/obsidian-second-brain) (snippet only)
- **Scheduled headless agents.**
  - weardo/brain runs `claude -p '/consolidate'` nightly from cron. Cron jobs work on a `brain-auto/YYYY-MM-DD` branch and open PRs, so "nothing touches the main branch without your approval." — [GitHub weardo/brain](https://github.com/weardo/brain) (snippet only)
  - Other write-ups use a Sunday cron for weekly review, and a daily-note template whose fixed sections a nightly agent fills in. One blog's flag syntax did not match the documented `claude -p` interface. — [bls-blog](https://bls-blog.pages.dev/blog/automated-weekly-reflection-system); [dev.to night shift](https://dev.to/sabahattink/how-i-automated-my-obsidian-vault-with-claude-it-now-works-the-night-shift-3gjl) (snippet only)
- **A weekly review prompt pattern:** "Review all Daily Notes from this week. Summarize key decisions, flag any tasks that appear open across multiple days," then write a dated note to `Reviews/`. — [MindStudio](https://www.mindstudio.ai/blog/how-to-build-ai-second-brain-obsidian-claude-code) (snippet only)

**Other conventions observed**
- Running `/init` inside the vault generates a starter CLAUDE.md, but the file goes stale as the vault evolves. — [DEV Community](https://dev.to/mibii/claude-code-obsidian-build-a-second-brain-that-actually-thinks-d61) (snippet only)
- A Claude Code plugin loads its working style only when a session starts in a folder containing `.obsidian/`. — [SmartAndPoint/obsidian-claude-code](https://github.com/SmartAndPoint/obsidian-claude-code) (snippet only)
- **AI-first "brain" folder with a reading path** (Hack-Log, Aug 27, 2026):
  - A mandatory `type` frontmatter field (Preferences / Decisions / Knowledge); 172 of 174 notes carry it.
  - A short `INDEX.md` (<200 lines, one line per note) that the agent reads at session start and appends to whenever a note is created.
  - A shallow hierarchy with descriptive filenames.

  — [Hack-Log (note.com)](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en)

### Inferences
- **The "index file" recurs independently.** Konik's overnight index, Hack-Log's INDEX.md, and Karpathy's wiki index all serve as a cheap, human-auditable alternative to embeddings for "ask my vault." It is probably the single highest-leverage artifact to have an agent maintain.
- **Self-improving instructions are a key practice.** Konik's "write the correction back into the skill/CLAUDE.md" keeps CLAUDE.md from going stale.
- **Read-heavy recipes give the best value per risk:** pattern-finding, indexing, health/orphan reports, MOC generation, cited synthesis into a separate output folder. Write-heavy recipes (rewriting existing notes, bulk retagging) are where every source adds PRs, branches, or plan mode.

### Gaps
- No published example found of an AGENTS.md specifically tuned for Codex in a vault. Multi-agent kits (obsidian-second-brain, kepano's skills) imply it works, but I found no write-up of Codex-specific vault workflows.
- No first-hand published recipe for "contradiction finding" or "literature-note drafting" beyond generic synthesis skills. Reitz's cross-temporal pattern queries are the closest.
- Claude Code hooks in vaults: no concrete published vault hook examples found beyond the claude-mem style memory-sync hooks (lucasrosati, snippet only). The Zander MCP write-guards (Q7) are the closest analogue.

## 2. MCP servers for Obsidian: which are maintained, what they expose, safety

### Takeaway
As of Nov 2026 there is still no first-party Obsidian MCP server. The Local REST API plugin itself serves MCP at `/mcp/` since v4.0 (May 2026), which makes the older mcp-obsidian wrapper largely redundant. The two maintained choices are cyanheads/obsidian-mcp-server, for the deepest REST-backed tools, and filesystem servers (official filesystem MCP or MCPVault), for no-Obsidian-running simplicity. If you already use Claude Code in the vault directory, you often don't need MCP at all.

### Cited Findings
- **No official server.** Obsidian ships an official CLI but no first-party MCP server; one guide says this as of August 2026. — [Morph guide](https://www.morphllm.com/obsidian-mcp-server) (snippet only)
- **Local REST API plugin** (coddingtonbear):
  - Serves MCP at `/mcp/` since v4.0 (May 2026).
  - API key sent as a bearer token; HTTPS on 127.0.0.1:27124 with a self-signed certificate; plain HTTP on 27123 off by default.
  - Requires Obsidian to be running.
  - ContextBolt calls it "best overall" because it is one install.

  — [ContextBolt, May 15 2026, updated Nov 1 2026](https://contextbolt.com/blog/obsidian-mcp-claude/). Caveat: ContextBolt sells a competing product. Sources disagree slightly on the v4.0/May date.
- **cyanheads/obsidian-mcp-server** (TypeScript, on the REST API):
  - 14 tools: section-aware PATCH, tag/frontmatter management, command-palette dispatch.
  - Search: plain text, JSONLogic, and BM25 via Omnisearch.
  - Command dispatch is off unless `OBSIDIAN_ENABLE_COMMANDS` is set.
  - v3.7.0 released October 2026; requires REST API ≥ 4.0.

  — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/). Noverload calls it the most actively maintained of 45+ Obsidian MCP servers tracked on PulseMCP. — [Noverload](https://noverload.com/blog/best-mcp-servers-personal-knowledge-2026) (snippet only)
- **MarkusPfundstein/mcp-obsidian** (Python, uvx, ~4.5k stars):
  - About 10 tools: list, read, full-text search, append, patch by heading or block, delete, daily-note helpers.
  - ContextBolt: "Skip mcp-obsidian unless your client forces it," because the plugin now serves MCP directly.

  — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/)
- **MCPVault** (`@bitbonsai/mcpvault`, renamed March 2026):
  - Filesystem-based; Obsidian need not be open.
  - AST-aware frontmatter preservation; filters `.obsidian` and system files.
  - A symlink path-traversal flaw was patched in v0.9.1 (March 2026); several April 2026 releases followed.

  — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/). One summary attributed the path-traversal fix to cyanheads instead, but the fetched ContextBolt article attributes it to MCPVault.
- **Official `@modelcontextprotocol/server-filesystem`.** Tools: list, read, write, edit, find by name, move. It has no content search and exposes only the folders you whitelist. ContextBolt recommends it as the fastest start. — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/)
- **Plugin-side MCP connectors:**
  - istefox "MCP Connector for Obsidian": runs inside Obsidian on loopback; Claude Desktop install via a `.mcpb` drag-and-drop file. — [GitHub istefox/obsidian-mcp-connector](https://github.com/istefox/obsidian-mcp-connector) (snippet only)
  - "Vault MCP Connector": public alpha, installed via BRAT. Its `propose_vault_write` tool "never edits a vault directly." — [Obsidian community plugin page](https://community.obsidian.md/plugins/vault-mcp-connector) (snippet only)
- **Safety note on Claude Code vs MCP.** Zander argues that Claude Code in a terminal, with permission prompts off and the vault open, is less safe than a narrow MCP server (fewer tools, scoped paths, a per-write approval prompt). — [zander.wtf, Sep 2026](https://zander.wtf/blog/obsidian-mcp-pi/)

### Inferences
- **Recommended default for Claude Desktop/mobile users:** Local REST API ≥ 4.0 with its built-in MCP, or cyanheads if you need frontmatter/tag tools.
- **For agents with shell access** (Claude Code/Codex in the vault): skip MCP and use files plus the Obsidian CLI and kepano skills.
- mcp-obsidian is effectively legacy for new setups.
- Prefer servers with an off-by-default command dispatch and a "propose write" mode.

### Gaps
- Star counts, last-commit dates, and full tool lists for most servers were not independently verified on GitHub; figures are from one vendor-authored comparison.

## 3. Claude Desktop / ChatGPT / Gemini / NotebookLM pointed at the vault

### Takeaway
Claude has the most mature path: Desktop config, `.mcpb` bundles, or remote custom connectors that work across Desktop, web, mobile, and Claude Code on one subscription. ChatGPT requires Developer Mode on a paid plan, which reportedly disables memory. NotebookLM is used as a read-only "study room": you export a focused folder, and you should not paste its output back into permanent notes.

### Cited Findings
- **Zander's remote connector (Sep 2026).**
  - Stack: headless obsidian-sync in Docker on a Raspberry Pi, a ~100-line FastMCP server, GitHub OAuth (one allowed account), and Tailscale Funnel. A public URL is needed because Anthropic's servers, not the phone, call the MCP server.
  - Added once as a custom connector, it works across the Mac app, claude.ai, the phone, and Claude Code on the subscription.
  - Tools: `list_notes`, `read_note`, `search_notes`, `write_note`, `append_note`.

  — [zander.wtf](https://zander.wtf/blog/obsidian-mcp-pi/); [gist](https://gist.github.com/mrmartineau/475dc3e8ffc6908f1493a05989a116ff)
- **ChatGPT.** Custom MCP needs Developer Mode (Pro/Business/Enterprise/Edu). A forum request says Developer Mode "completely disables memory features" and that Obsidian is not a native ChatGPT connector; this may be dated. — [Obsidian Forum](https://forum.obsidian.md/t/integration-request-obsidian-openai-chatgpt-connectors/106924); [LobeHub listing](https://lobehub.com/it/mcp/breannasalah-mcp-obsidian-universal) (snippet only)
- **NotebookLM: vault to NotebookLM.**
  - The "Context Pack for NotebookLM" plugin strips frontmatter, wikilinks, embeds, and comments, adds each note's vault path, and exports a ZIP (whole vault, folder, tag, or note).
  - `obs2nlm` merges a vault into a single Markdown file.
  - NotebookLM drops images and tables from Markdown, so export rich notes to PDF.

  — [Context Pack plugin](https://community.obsidian.md/plugins/context-pack-for-notebooklm); [obs2nlm on PyPI](https://pypi.org/project/obs2nlm/); [HubSite365](https://www.hubsite365.com/en-ww/crm-pages/notebooklm-obsidian-changed-how-i-retain-information.htm) (snippet only)
- **NotebookLM: back into the vault.**
  - nb2ob: fetches notebooks, runs an LLM clustering pipeline, and writes via the REST API.
  - A `notebooklm-import` Claude skill converts sources to wikilinked notes; it needs Dataview and cookie re-login.
  - Practical advice: keep each notebook to one topic, and don't paste NotebookLM output straight into permanent notes.

  — [nb2ob](https://github.com/DaviAlcanfor/nb2ob); [skills.sh notebooklm-import](https://skills.sh/artemxtech/personal-os-skills/notebooklm-import) (snippet only)
- **Readwise.**
  - The Aug 2026 Reader update lists "Global Ghostreader" and MCP; Ghostreader can triage the inbox and organize the library. — [Readwise update Aug 2026](https://readwise.io/reader/update-aug2026) (snippet only)
  - BibiGPT dates the Readwise MCP+CLI launch to Mar 20, 2026, while ContextBolt's directory claims no first-party server yet. These conflict. — [BibiGPT](https://bibigpt.co/blog/posts/readwise-lookup-gpt55-mcp-bibigpt/); [ContextBolt Readwise](https://contextbolt.com/tools/mcp-server-directory/readwise/)
  - Readwise's own April 15, 2026 newsletter says MCP access was expanded to Notion and Perplexity. It also introduced **Wikiwise**: an experimental native Mac app where you point an agent at a markdown folder, and it reads added sources, writes summary pages, cross-references, and keeps things consistent (effectively a productized Karpathy-style LLM wiki). — [WiseUp Vol. 63](https://wiseup.readwise.io/wiseup-vol-63-introducing-wikiwise-single-re-export-to-obsidian-and-email-filtering-in-reader/)

### Inferences
- **Claude via a remote MCP connector is how people get "ask my vault" on mobile.** It requires the vault to live on an always-on machine; headless Obsidian Sync makes this feasible.
- **NotebookLM is best for bounded study of one topic.** Examples: audio overviews, or Q&A with citations over an exported folder. It is a poor fit for whole-vault querying.

### Gaps
- No reliable 2026 source on Gemini (app/CLI) workflows with Obsidian specifically, beyond multi-agent kits listing Gemini CLI support.
- Could not verify current ChatGPT Developer Mode/memory behavior as of Nov 2026.

## 4. Local models for privacy (Ollama, LM Studio, MLX)

### Takeaway
Local models are "good enough" for bounded tasks: summarizing one note or clip, tagging suggestions, Web Clipper interpretation, transcription cleanup. Typical 2026 picks are mid-size Qwen3-family and Gemma-family models. Agentic whole-vault work is still done with frontier cloud models in all published practitioner setups found. Model-version names in 2026 roundups are inconsistent and largely unverified.

### Cited Findings
- **Summarization picks.** One guide names Gemma 4 12B (256K context, ~8 GB) as the default local summarizer on Ollama, with Qwen3.8 27B / Gemma 4 31B for 24 GB VRAM. — [PromptQuorum](https://www.promptquorum.com/prompt-bites/best-local-llm-document-summarization) (snippet only; it states its picks rest on specs and vendor results, not its own benchmark)
- **Qwen3 as the general pick.** "For most people the best local LLM is Qwen3 in a size that fits their GPU." Hugging Face's roundup calls Qwen3 the best overall family (Apache 2.0, size range). — [Layer3Labs](https://www.layer3labs.io/guides/best-local-llms); [Hugging Face blog](https://huggingface.co/blog/daya-shankar/open-source-llm-models-to-run-locally) (snippet only)
- **16 GB GPU tier.** For summarization on a 16 GB consumer GPU, qwen3:14b at Q4_K_M (~10 GB) is cited for strong instruction-following and ~128K context. — [summarize.sh docs](https://summarize.sh/docs/ollama.html) (snippet only)
- **MLX on Apple Silicon.** Ollama 0.40 (Sept 2026) reportedly runs Gemma 4 and Qwen 3.5/3.6 on MLX by default on Apple Silicon. This is a single unverified claim. — [PromptQuorum](https://www.promptquorum.com/local-llms/top-open-source-models-ollama) (snippet only)
- **Web Clipper Interpreter on Ollama** (official docs):
  - No API key needed; the model ID must match Ollama's exactly.
  - Ollama must be started with `OLLAMA_ORIGINS=moz-extension://*,chrome-extension://*,safari-web-extension://*`, or the extension gets a 403.
  - Ollama's default 2048-token context easily overflows on long pages.

  — [Obsidian Help: Interpreter](https://help.obsidian.md/web-clipper/interpreter)
- **Local endpoints in plugins.** The "AI Notes" plugin supports llama.cpp, LM Studio, Ollama, and whisper.cpp endpoints. — [AI Notes plugin](https://community.obsidian.md/plugins/ai-notes) (snippet only)

### Inferences
- **Practical rule:** use local models for per-note transforms (summarize, extract properties, interpret a clip) and for anything touching sensitive notes. Use a frontier model via Claude Code for multi-file reasoning on the non-sensitive part of the vault, or keep a separate sensitive vault, as Konik does by keeping private data out entirely.
- **Raise Ollama's context (`num_ctx`) when clipping.** The 2048 default silently truncates.

### Gaps
- No head-to-head benchmark of local models on vault-specific tasks (link suggestion, MOC generation) was found.
- Exact current model names (e.g., "Qwen3.8", "Gemma 4 12B") could not be confirmed against official release pages; treat them as indicative.

## 5. AI-assisted capture: transcription, voice, meetings, web clipping, Readwise

### Takeaway
Capture is where AI most clearly adds value without degrading the vault, as long as the raw source is kept and the AI output is labeled. The 2026 toolset is fragmented:
- Many small Whisper/LLM plugins with low install counts.
- Web Clipper Interpreter templates.
- Custom capture bots such as Konik's Telegram bot.
- Readwise's Ghostreader and MCP.

### Cited Findings
- **Voice and meeting plugins.**
  - "AI Audio Transcription and Summary" (premium; macOS/iOS): transcribes with Whisper or Gemini, then summarizes with Claude or GPT.
  - "ReWrite (Voice Notes)": tested with local whisper.cpp, Mistral Voxtral, and AssemblyAI.
  - "Voice Scribe": offline Whisper.
  - "Meeting Notes": right-click a recording or transcript to generate meeting notes.
  - LexVoice: meeting, interview, and discussion notes plus action items; no mobile support.
  - nikdanilov "Whisper": the long-standing OpenAI-Whisper plugin.

  — [AI Audio Transcription](https://community.obsidian.md/plugins/ai-audio-transcription-summary); [ReWrite](https://community.obsidian.md/plugins/rewrite-voice-notes); [Voice Scribe](https://community.obsidian.md/plugins/voice-scribe); [Meeting Notes](https://community.obsidian.md/plugins/meeting-notes); [LexVoice](https://github.com/Lynn-x/LexVoice); [Whisper](https://community.obsidian.md/plugins/whisper) (snippet only)
- **Caveat on maturity.** Most voice-plugin listings show only ~26–563 downloads, so maintenance and quality are unverified. — [search summary of obsidianstats/community listings](https://obsidianstats.com/tags/voice) (snippet only)
- **Konik's dictation capture.** She built a Telegram bot and Obsidian plugin for inbox capture, and dictated much of her article into it. The bot did not process messages sent before the plugin existed. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **Agent-driven URL capture.** `/vault-capture` turns a URL into a structured note via defuddle, filed into a project folder. — [az9713](https://github.com/az9713/claude-code-obsidian)
- **How Interpreter sends data.** Web Clipper's Interpreter sends page content plus all template prompts to the chosen model in one request. — [Obsidian Help: Interpreter](https://help.obsidian.md/web-clipper/interpreter)
- **Labeling clipper summaries.** An author cited by Hack-Log labels AI summaries from the web clipper as AI-generated, quotes them, and deletes them later. — [Hack-Log](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en)
- **Readwise.** See Q3 (Ghostreader inbox triage; MCP; the Wikiwise experiment).

### Inferences
- **Good pattern:**
  1. Keep the raw transcript or clip in a `Sources/` or `Clippings/` folder that is read-only to agents.
  2. Put the AI summary in a property or a clearly marked callout.
  3. Let the human write the "why this matters" line.

  This keeps the generation effect where it matters.
- **Pick local whisper.cpp** when audio contains other people (meetings), for privacy and consent reasons.

### Gaps
- No usage data on which voice plugins are most adopted or maintained in late 2026.
- No published Interpreter prompt templates from well-known practitioners were fetched; one paywalled/lead-gen template exists at [Linking Your Thinking](https://www.linkingyourthinking.com/thank-you/my-web-clipper-prompt) (not fetched).

## 6. Spaced repetition / AI-generated flashcards from notes: evidence

### Takeaway
Evidence favors self-generated cards (generation effect), with a moderate effect size from Pan et al. 2022, though not every study agrees. AI-generated cards have quality problems, and there are no strong head-to-head trials yet. Practitioner consensus: AI drafts, human edits and prunes, then SRS. Treat AI cards as a time-saver, not a learning shortcut.

### Cited Findings
- **Pan et al. (2022).** Six experiments: user-generated digital flashcards beat premade ones, with an estimated d ≈ 0.45 on memory and d ≈ 0.29 on application. — reported in [Eva Keiffenheim, "When AI Flashcards Pollute Your Anki Deck"](https://evakeiffenheim.substack.com/p/when-ai-flashcards-pollute-your-anki-deck-and-the-4-step-workflow-that-makes-them-useful-instead) (secondary; original not fetched)
- **Contrary result.** Lin & McDaniel (2018): students who made their own flashcards did not learn more, though they spent more time. — [Learning and the Brain blog](https://www.learningandthebrain.com/blog/should-students-make-their-own-flashcards-take-ii/)
- **AI card quality.** A 2026 benchmark reportedly found that even the top model produced unusable cards 36% of the time. This is unverified; it is secondhand via Keiffenheim. — [Keiffenheim](https://evakeiffenheim.substack.com/p/when-ai-flashcards-pollute-your-anki-deck-and-the-4-step-workflow-that-makes-them-useful-instead)
- **Trials are early.**
  - A medical-education preprint built an LLM-to-Anki pipeline, but the retrieved content covered design, not outcomes. — [medRxiv 2025](https://www.medrxiv.org/content/10.1101/2025.05.13.25327518.full.pdf)
  - A registered RCT on AI flashcards in undergraduate biochemistry showed no results yet. — [ClinicalTrials.gov NCT07835217](https://clinicaltrials.gov/study/NCT07835217)
- **Hybrid recommendation.** Vendor and practitioner sources recommend AI drafting with human review. — [RemNote](https://www.remnote.com/blog/traditional-vs-ai-flashcards); [Cramd](https://trycramd.com/blog/should-you-use-ai-flashcards) (both vendors with incentives)

### Inferences
- **For a vault:** generate candidate cards from *your own* permanent notes (not clippings), and require an edit pass that deletes most of them. Use AI more for *retrieval prompts* ("quiz me on this MOC") than for persisting card decks.

### Gaps
- No peer-reviewed head-to-head RCT of AI-generated vs self-generated cards with retention outcomes was found as of Nov 2026.
- No specific Obsidian plugin (e.g., Spaced Repetition + AI) usage evidence was gathered.

## 7. Guardrails: provenance, separation, git review, prompt injection

### Takeaway
Serious practitioners layer these controls:
1. Backups and git, as distinct things.
2. Folder ownership: read-only sources, an agent-only output folder, and propose-before-edit for human notes.
3. Claude Code deny rules, since CLAUDE.md is advice, not a control.
4. Branch/PR review for bulk or scheduled agents.
5. Treating clipped content as untrusted input.

Prompt injection via Web Clipper clippings is a real, documented loop, and pattern-matching guards only partially mitigate it.

### Cited Findings
- **aident.ai's safety recipe.**
  - Copy the whole vault, including `.obsidian`, before the agent runs. "Sync is not a backup."
  - Git checkpoint until `git status --short` is empty; git doesn't track everything, such as some attachments.
  - Folders: `00 Inbox`, `10 Sources` (read-only), `20 Notes` (propose edits first), `90 Agent Output`.
  - Deny rules in `.claude/settings.local.json`: `"deny": ["Edit(./10 Sources/**)", "Bash(rm *)", "Bash(mv *)"]`. Deny is evaluated before allow; test the rule on a disposable file; check `/permissions`; never use `bypassPermissions` on a live vault.
  - Start in Plan mode. Expect one new file, then verify with `git diff --name-status` that there are no `D`/`R`/unexpected `M` entries.
  - "CLAUDE.md instructions are not a security control."

  — [aident.ai](https://aident.ai/blog/claude-code-obsidian-without-losing-notes)
- **Provenance.**
  - aident: cite source notes with links, keep unknown values marked unknown, and keep generated summaries in the review folder until a person verifies them. — [aident.ai](https://aident.ai/blog/claude-code-obsidian-without-losing-notes)
  - Another guide recommends marking agent-written content in frontmatter, "since you'll want to review agent-synthesized content differently." — [MindStudio](https://www.mindstudio.ai/blog/ai-second-brain-claude-code-obsidian-architecture) (snippet only)
  - Hack-Log uses a mandatory `type` property to separate personal decisions from researched knowledge. — [Hack-Log](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en)
- **Review-before-merge.**
  - Konik uses PRs for bulk metadata migrations and git commits after every change. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
  - weardo/brain's nightly cron writes only to dated branches with PRs. — [weardo/brain](https://github.com/weardo/brain) (snippet only)
  - Claudesidian imports old vaults to `OLD_VAULT/` instead of merging. — [Claudesidian](https://github.com/heyitsnoah/claudesidian)
- **Prompt-injection loop.** A Reddit report described Claude reading clipped third-party text while also being able to write to the vault. Zander's guards:
  - The `Clippings/` folder is read-only (`UNTRUSTED_FOLDERS`).
  - Search hits in Clippings return only path and line number, never text, so any clipping read is a visible `read_note` call.
  - `CLAUDE.md`/`AGENTS.md` are unwritable by tools.
  - Zero-width, bidi, and Unicode-tag characters are stripped on read and refused on write.
  - Chat-template markers (`<|im_start|>`) are refused.
  - A nightly Python scan checks for hidden text, HTML comments, CSS-hidden text, and "ignore previous instructions" phrasing.
  - Dataview JS and Templater stay disabled, since agent-written notes could become executable code.
  - He admits the guards can't catch a visible instruction; the last line is the per-write approval prompt plus Obsidian Sync version history, and "Always allow" on write tools removes it.

  — [zander.wtf](https://zander.wtf/blog/obsidian-mcp-pi/)
- **Injection risk in a vault plugin.** A plugin's security notes: if the vault contains clipped pages or pasted emails, "that content can contain instructions that the model may follow. With a permissive tool allowlist this becomes a path to unintended file edits or command execution." — [Claude Vault Assistant plugin](https://community.obsidian.md/plugins/claude-vault-assistant) (snippet only)
- **Snyk flag.** Snyk flagged an Obsidian CLI agent skill as a medium-risk indirect-injection vector, because it lets the agent load arbitrary web pages and read their DOM. — [skills.sh Snyk audit](https://skills.sh/openclaw/skills/obsidian-cli/security/snyk) (snippet only)
- **Web Clipper Interpreter mixing.** Interpreter puts untrusted page text and template prompts in the same request. Official docs don't describe injection defenses. — [Obsidian Help: Interpreter](https://help.obsidian.md/web-clipper/interpreter)
- **Security fix.** MCPVault fixed a symlink path-traversal vulnerability in v0.9.1 (Mar 2026). — [ContextBolt](https://contextbolt.com/blog/obsidian-mcp-claude/)

### Inferences
- **Minimum viable guardrail set for a vault agent:**
  1. git plus an independent backup.
  2. Deny-edit on `Sources/` and `Clippings/` and on CLAUDE.md itself.
  3. An agent-only output folder.
  4. An `ai-generated: true` (or `type`/`source`) property on anything the agent creates.
  5. Branch/PR for any scheduled or bulk run.
  6. No "always allow" on writes when clippings are in scope.
  7. Disable Templater/DataviewJS execution on agent-writable folders.

### Gaps
- No standard or widely adopted provenance property name was found. `ai-generated: true` is a convention suggestion, not an observed standard.
- No formal study of injection incidents in personal vaults was found; evidence is anecdotal (one Reddit report, relayed by Zander).

## 8. What skeptics and power users say works vs. hurts

### Takeaway
Most practitioners converge on a split. AI as reader, indexer, linter, and pattern-finder over *your* writing makes the vault more valuable. AI as author of notes you never wrestled with dilutes it, causing ownership loss and making your thoughts hard to tell from the model's. A sharp 2026 counterpoint argues that the deciding factor is whether notes sit on a path that actually gets read, not who wrote them.

### Cited Findings
- **The "Don't put AI-written notes into Obsidian" essay** (143 HN points). Mixing AI text into the vault makes you lose the ability to tell your own thoughts from AI output, and ideas merely suggested by AI lack ownership, so you never finish them. AI is acceptable for research and finding related notes, but not for tagging, organizing, or long summaries. — reported by [Hack-Log, Aug 27 2026](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en). The original's author and URL were not confirmed; Hack-Log links ssp.sh "Using Obsidian with AI."
- **Hack-Log's counter-data.**
  - The AI-facing "brain" folder: 174 notes, 94 (54%) updated within 30 days.
  - Five human-facing folders: 134 notes, 0 updated within 30 days, 1 within 90 days. The 60_Ideas folder had stalled for 137 days.
  - Conclusion: "the deciding factor is whether a note is on a path that gets read regularly."

  — [Hack-Log](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en)
- **A middle position.** Other writers keep AI limited to suggesting related notes, to avoid building "one more storehouse of AI-written text." A 467-note vault is described as "a filing cabinet with better indexing," with AI reading from it. — [search summary](https://note.com/hacklog_stealth/n/n8e1786d1458e?hl=en); [Reitz](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code)
- **Power-user positives.**
  - Reitz: "This is not search. Search returns documents. Claude Code returns understanding." Structure (numbering, frontmatter, CLAUDE.md) is what makes AI collaboration accumulate, whereas ephemeral chats don't. — [Reitz](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code)
  - Konik: "not magic," not replacing her job. The value is that background tasks actually get done. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)
- **Maintenance framing.** Pro-AI guides argue that unmaintained vaults become a "graveyard of notes" and that "most second brains quietly die." One DEV post frames the setup as "Claude takes care of memory while you focus on thinking," which is the framing skeptics challenge. — [DEV Community](https://dev.to/joao_victorsouza_ef8ff8a/obsidian-claude-code-as-a-second-brain-1n71); [XDA](https://www.xda-developers.com/pointed-claude-code-at-obsidian-vault-it-became-second-brain/) (snippets only)
- **Mainstreaming.** Obsidian plus Claude is described as the "default second brain stack" (Aug 2026). Kevin Stratvert's July 29, 2026 Obsidian tutorial had 139k+ views and shows AI plugged in. — [ProudFrog](https://proudfrog.com/en/news/2026-08-05-obsidian-claude-becomes-default-second-brain); [Mean CEO newsletter](https://blog.mean.ceo/obsidian-news-october-2026/) (snippets only; promotional)
- **Konik's operational costs.** Bulk agent edits stress Obsidian Sync and cause cache staleness. — [Konik](https://www.eleanorkonik.com/p/claude-obsidian-got-a-level-up)

### Inferences
- **Workflows that make the vault more valuable:**
  - Agent-maintained index / MOC files.
  - Health reports (orphans, broken links, missing properties).
  - Cross-temporal pattern questions over your own journals (Reitz).
  - Cited synthesis into a separate folder.
  - Metadata migrations via PR.
  - Inbox triage that *proposes* filing.
  - Capture cleanup with the raw source preserved.
  - Thinking-partner modes that ask questions (Claudesidian `/thinking-partner`).
- **Workflows that degrade it:**
  - Agents writing permanent/evergreen notes in your voice.
  - Auto-tagging and auto-linking at scale without review, which produces link spam and a meaningless graph.
  - Persisting long AI summaries of clippings as if they were notes.
  - Unreviewed AI flashcard decks.
  - Running write-enabled agents over un-quarantined clippings.
- **Resolving the "who wrote it" vs "is it read" disagreement.** Use a `type`/provenance property plus separate folders, so AI-maintained scaffolding (indexes, MOCs, summaries) stays on the read path while human-authored notes stay clearly identifiable.

### Gaps
- The original "Don't put AI-written notes into Obsidian" essay and its HN thread were not located directly. Reddit (r/ObsidianMD, r/ClaudeAI) and HN threads were not surfaced by search, so community-sentiment claims rest on blog-level sources.
- kepano's (Obsidian CEO) own late-2026 stance on agents writing into vaults was not found in this pass.
