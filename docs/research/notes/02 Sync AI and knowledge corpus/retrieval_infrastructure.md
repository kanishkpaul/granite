# Retrieval Infrastructure on Top of an Obsidian Vault (as of Nov 2026)

Scope note: Research done 2026-11-03 with about 15 web search/fetch calls. Primary sources fetched directly: the qmd GitHub README, Anthropic's Contextual Retrieval post, and the Smart Connections GitHub README. Much of the rest comes from secondary or aggregator sources (SEO guides, vendor comparisons), and those are flagged where they matter. A few items cite well-known primary URLs from prior knowledge that I did not re-fetch this session; they are marked "(not re-fetched)".

---

## Q1. Embedding models in 2026 for personal notes: local vs API (quality, cost, privacy, multilingual)

### Takeaway
The open-weight Qwen3-Embedding family (0.6B/4B/8B) is the most consistently cited top open model on MTEB in 2026. EmbeddingGemma-300M is the practical small local default and is what qmd ships with. Hosted APIs are cheap: OpenAI text-embedding-3-small and voyage-4-lite cost about $0.02 per 1M tokens, so embedding a 50k-note vault costs a few dollars at most. For a personal vault the real tradeoffs are privacy and multilingual coverage, not cost or a few MTEB points.

### Cited Findings
- **Qwen3-Embedding-8B** scores about 75.2 on MTEB(eng, v2), and QZhou-Embedding about 75.97. Both are Apache 2.0, per a snapshot checked 14 Oct 2026. A May 2026 source gives Qwen3-Embedding-8B ≈75.1 and 4B ≈72.4. — [presenc.ai: Best Open-Weight Embedding Models 2026](https://presenc.ai/research/best-open-weight-embedding-models-2026); [hussain-nazary: Top 10 Embedding Models 2026](https://hussain-nazary.github.io/top-10-embedding-models-2026.html)
- On MTEB Multilingual v2, Microsoft's **harrier-oss-v1-27b** reportedly leads at 74.27 (MIT license, 27B params, 32K context). This is too large for most laptop use. — [presenc.ai](https://presenc.ai/research/best-open-weight-embedding-models-2026) (single source, unverified)
- **EmbeddingGemma** scores 69.67 on MTEB(eng, v2), with 768 dims and a 2,048-token context. **Qwen3-Embedding-0.6B** scores 70.47 on the same benchmark. — [presenc.ai](https://presenc.ai/research/best-open-weight-embedding-models-2026) (single source)
- The Qwen3 Embedding paper says the 4B/8B models achieve the best performance, and that the 0.6B model trails only Gemini-Embedding on the multilingual benchmark. The family also ships matching rerankers. — [Qwen3 Embedding paper, arXiv 2506.05176](https://arxiv.org/pdf/2506.05176)
- Older leaderboard snapshots disagree. A CodeSOTA page dated Apr 2026 shows NV-Embed-v2 (72.31) as leader, which suggests a different task mix or stale data. Check the live HF MTEB space before relying on exact numbers. — [CodeSOTA MTEB](https://www.codesota.com/benchmark/mteb)
- Ollama-friendly local options commonly recommended for Obsidian plugins are **nomic-embed-text** and **mxbai-embed-large**. — [promptquorum: Local LLM with Obsidian 2026](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026); [morphllm: Best Ollama Embedding Models 2026](https://www.morphllm.com/ollama-embedding-models)
- Local throughput (secondary benchmark): nomic-embed-text on an M3 Pro took about 10 min for a 5,000-note vault and about 75 min for 20,000 notes. — [promptquorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026) (unverified, SEO-style guide)
- **API pricing, per 1M tokens, 2026 list prices from aggregators:**
  - OpenAI text-embedding-3-small: $0.02 ($0.01 batch).
  - OpenAI text-embedding-3-large: $0.13.
  - Voyage voyage-4-lite: $0.02. voyage-4: $0.06. voyage-4-large: $0.12. Voyage includes 200M free tokens on the v4 generation.
  - Cohere embed-v4: $0.12 for text. Some sites list conflicting lower prices.
  - Gemini Embedding 2: $0.20 for text (batch is half price). gemini-embedding-001: $0.15.
  - Sources: [embeddingcost.com/compare](https://embeddingcost.com/compare); [aiapiprices.com](https://aiapiprices.com/embeddings-api-pricing/); [devtoollab](https://devtoollab.com/blog/best-embedding-models-apis). Verify on the official pricing pages.
- In Anthropic's Contextual Retrieval experiments (2024), **Gemini Text 004 and Voyage** were the most effective of the embeddings tested. Contextualization helped every embedding model. — [Anthropic: Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval)

### Inferences
- Rough cost math: 50k notes at about 1k tokens each is about 50M tokens. At $0.02/M that is about **$1 per full embed** with OpenAI small or voyage-4-lite. Even voyage-4-large comes to about $6. For a single user, API cost is negligible, so privacy is the deciding factor.
- Recommended local default on Apple Silicon:
  - **EmbeddingGemma-300M** or **Qwen3-Embedding-0.6B**, run through llama.cpp/Ollama/MLX. Both are small enough to re-embed a whole vault in minutes to tens of minutes.
  - **Qwen3-Embedding-4B** if quality and multilingual coverage (CJK etc.) matter and you accept slower indexing.
  - **bge-m3** is still a good multilingual choice that also produces sparse vectors, but it has been surpassed on MTEB. (BGE-M3 was not re-verified this session.)
- MTEB differences of 2–5 points matter much less for a personal vault than chunking, hybrid BM25, and reranking (see Q3).

### Gaps
- Could not load the live MTEB leaderboard directly. Exact scores for nomic-embed v2, gte-modernbert, mxbai, bge-m3, OpenAI v3, and Voyage-4 on the same v2 benchmark are not verified here.
- No primary benchmark found for embedding speed on M-series Macs per model, beyond the one SEO guide above.

---

## Q2. Vector stores for local/personal use, and how Obsidian plugins store indexes

### Takeaway
At personal scale (≤ about 1M chunks), every embedded store is fast enough. Choose for zero-ops and file-portability. **sqlite-vec + SQLite FTS5** (the qmd approach) and **LanceDB** are the strongest embedded, zero-server choices. Chroma is the Python-prototyping default. Qdrant and pgvector are overkill unless already running. Obsidian plugins keep their own private indexes inside the vault (e.g., Smart Connections' `.smart-env/`), and these should be excluded from sync.

### Cited Findings
- **sqlite-vec** is a pure-C SQLite extension that adds vector search via virtual tables. It lacks advanced ANN index types and GPU support, and is regarded as a good "minimal infra" choice for smaller local setups. — [Actian: comparing embedded vector DBs](https://www.actian.com/blog/developer/comparing-embedded-vector-databases/); [Reddit snapshot Feb 2026](https://reddit.sentinel-team.org/posts/1r3y4ys/snapshots/2026-02-21T04%3A11%3A39.063959Z)
- **LanceDB** is described as the only embedded vector DB with first-class Python, JS/Node, and Rust support, and as strong for multimodal and data-pipeline workloads. — [Actian](https://www.actian.com/blog/developer/comparing-embedded-vector-databases/); [aloa.co](https://aloa.co/ai/comparisons/vector-database-comparison/best-embedded-vector-databases)
- **Chroma** is described as the default embedded vector DB for Python devs and best for a proof-of-concept or a local LLM pipeline. Its local mode works like opening a SQLite file. — [encore.dev](https://encore.dev/articles/best-vector-databases); [palema substack: Lance vs Chroma](https://palema.substack.com/p/vector-databases-lance-vs-chroma)
- **Qdrant** is positioned for production at more than a few million vectors. "Qdrant Edge" (in-process) was reportedly GA in June 2026. — [kunalganglani: Qdrant vs Chroma 2026](https://www.kunalganglani.com/blog/qdrant-vs-chroma.md); [Actian](https://www.actian.com/blog/developer/comparing-embedded-vector-databases/) (vendor-written comparison)
- **qmd** stores everything in one SQLite file (`~/.cache/qmd/index.sqlite`): BM25 via **FTS5** and vectors via **sqlite-vec**, one vector index per collection. — [tobi/qmd README](https://github.com/tobi/qmd)
- **Smart Connections** keeps its index in a `.smart-env/` directory in the vault. The README tells users to exclude it from third-party sync tools. The index stays in sync by listening to Obsidian events, and sources are re-imported after a model change. The plugin ships a built-in local embedding model, and API-based model integrations moved to "Smart Chat Pro". v4, 5.5k stars. — [brianpetro/obsidian-smart-connections](https://github.com/brianpetro/obsidian-smart-connections)
- A secondary guide says the `.smart-env/` index syncs fine via Obsidian Sync but must be regenerated per device with iCloud/Git, and that only new or modified notes are re-embedded. — [promptquorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026) (partly contradicts the README's "exclude from sync" advice; treat as unverified)
- **Obsidian Copilot** "Vault QA":
  - Builds a vector index with the chosen embedding model. The index is reportedly stored in the plugin's config folder inside the vault.
  - The official listing now says semantic indexing is **optional** behind a "Semantic Search" toggle, and vault search works without an index.
  - Changing the embedding model requires a rebuild, and "Force Re-index" is advised after major changes.
  - Sources: [community.obsidian.md/plugins/copilot](https://community.obsidian.md/plugins/copilot); [apiyi docs: Obsidian Copilot](https://docs.apiyi.com/en/scenarios/chat/obsidian-copilot); [bestllmfor guide](https://bestllmfor.com/guide/obsidian-llm-local-ollama/)

### Inferences
- Copilot making embeddings optional matches the broader 2025–26 move toward lexical/agentic search as the default (see Q6).
- Recommended stack for a DIY build:
  - Use a single SQLite file with FTS5 + sqlite-vec, or LanceDB, which has built-in FTS/hybrid. Store it **outside the vault**, or in a dot-folder excluded from Obsidian Sync and iCloud.
  - Treat the index as a rebuildable cache, with the Markdown files as the source of truth.
- Brute-force (flat) search over 50k notes × ~5 chunks = 250k vectors × 768 dims runs in milliseconds on an M-series CPU. ANN indexes are optional at this scale. (This is a standard engineering estimate, not from a cited benchmark.)
- Turbopuffer, pgvector, and DuckDB VSS: there is no reason for a single user to adopt them unless already in the stack. Turbopuffer is a hosted object-storage-backed service, so it is not local or private.

### Gaps
- Did not verify current release dates or versions for sqlite-vec, LanceDB, Chroma, or DuckDB VSS (the DuckDB VSS extension's persistence was historically experimental; not re-checked).
- Smart Connections' default embedding model name and on-disk format were not stated in the README. Older versions used small BGE/TaylorAI models (not verified for v4).
- Copilot's storage backend (Orama vs other) was not confirmed.

---

## Q3. Chunking, contextual retrieval, hybrid BM25+vector, reranking, metadata filtering

### Takeaway
The highest-ROI levers for a Markdown vault are:
1. Heading-aware chunks of a few hundred to about 900 tokens.
2. Hybrid BM25 + vector fused with Reciprocal Rank Fusion.
3. A local cross-encoder or LLM reranker.

Anthropic's Contextual Retrieval showed these compound: 35% fewer retrieval failures from contextual embeddings, 49% with contextual BM25 added, and 67% with reranking added. YAML frontmatter should become filterable metadata columns.

### Cited Findings
- **Anthropic Contextual Retrieval** (Sept 2024): failure rate is 1 − recall@20, baseline 5.7%.
  - Contextual Embeddings: −35% (to 3.7%).
  - Plus Contextual BM25: −49% (to 2.9%).
  - Plus reranking: −67% (to 1.9%).
  - Setup: retrieved top-150 chunks, reranked with Cohere, kept the top 20. Passing 20 chunks beat passing 5 or 10.
  - Cost: about **$1.02 per 1M document tokens**, one-time, using prompt caching (assuming 800-token chunks, 8k-token docs, 100 tokens of context per chunk).
  - Advice: keep chunks to no more than a few hundred tokens. **If the knowledge base is under 200,000 tokens, skip RAG and put it all in the prompt** with prompt caching.
  - Source: [Anthropic: Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval)
- **qmd's pipeline** is a concrete 2026 reference design:
  - Chunks of about 900 tokens with 15% overlap, with regex break points that prefer Markdown headings, code fences, horizontal rules, and paragraph breaks, and never split code blocks.
  - LLM query expansion into typed sub-queries (lex / vec / HyDE) using a fine-tuned 1.7B model.
  - BM25 (FTS5) and vector (sqlite-vec) results fused with **RRF (k=60)**.
  - Reranked by **qwen3-reranker-0.6b**, then blended with position-aware weights.
  - A `metadata` tool lets you discover and filter on metadata keys.
  - All models run locally as GGUF files via node-llama-cpp.
  - Source: [tobi/qmd README](https://github.com/tobi/qmd)
- The Qwen3 family includes **Qwen3-Reranker** models released alongside the embedders. — [Qwen3 Embedding paper](https://arxiv.org/pdf/2506.05176)
- **Late chunking** (Jina, 2024): embed the whole long document with a long-context embedder, then pool token embeddings per chunk, so each chunk vector carries document context without an LLM call. — [Late Chunking, arXiv 2409.04701](https://arxiv.org/abs/2409.04701) (not re-fetched)

### Inferences
- Recommended chunking for Obsidian notes:
  - **Short notes (< ~800 tokens, the majority in most vaults) become one chunk each.**
  - Longer notes are split at H1/H2/H3 boundaries, and each chunk is prefixed with `note title > heading path` plus selected frontmatter (tags, type, date). This "poor man's contextual retrieval" is free and captures much of the benefit of LLM-generated chunk context for well-titled notes.
  - Reserve full LLM contextualization (Anthropic-style) for PDFs and long imported documents, where chunks lose context. At $1/M tokens via Claude Haiku with caching it is cheap, or it can be done locally with a small model.
- Treat wikilinks `[[...]]` and tags as BM25-friendly tokens. Keep aliases from frontmatter in the indexed text.
- Metadata filtering: parse YAML frontmatter into typed columns (date, tags[], type, status, project) in SQLite/LanceDB, and apply them as pre-filters before vector or BM25 search.
- Retrieve about 20 chunks for the LLM, per Anthropic. For agent use via MCP, return snippets plus paths and let the agent `get` full notes.

### Gaps
- No head-to-head benchmark found comparing late chunking vs contextual retrieval vs heading-prefix on personal Markdown corpora.
- No benchmark found for local reranker quality (bge-reranker-v2-m3, mxbai-rerank, Qwen3-Reranker, Jina reranker) on notes. Choosing qwen3-reranker-0.6b follows qmd's default, not a measured comparison.

---

## Q4. Knowledge-graph approaches: GraphRAG, LightRAG, the wikilink graph, Cognee, Graphiti/Zep

### Takeaway
LLM-extracted knowledge graphs (GraphRAG, LightRAG) help mainly with global "sensemaking" questions over large corpora. Independent re-evaluations show their gains over naive RAG are much smaller than self-reported, and they cost many LLM calls to index and keep fresh. For a personal vault, the **existing wikilink/backlink graph is a free, human-curated KG**. Using it for 1-hop expansion of hybrid-search hits is the pragmatic choice. Temporal graph memory (Graphiti/Zep, Cognee) suits agent conversation memory more than a static notes corpus.

### Cited Findings
- An unbiased re-evaluation (2025) found LightRAG's win rate vs naive RAG on the Agriculture dataset dropped from the reported 66.70% to **39.06%**, with tie rates often above 20%. GraphRAG-style methods become more effective as datasets scale up. — [arXiv 2506.06331: "How Significant Are the Real Performance Gains?"](https://arxiv.org/pdf/2506.06331)
- **WildGraphBench** (2026): on one table, LightRAG hybrid scored highest (71.16) vs MS GraphRAG global (65.38) and BM25 (26.92). On other subsets MS GraphRAG global or local won, so no method dominates. — [arXiv 2602.02053](https://arxiv.org/pdf/2602.02053)
- LightRAG's "less than 100 tokens vs GraphRAG's 610,000 tokens" claim refers to the **retrieval phase only**, not indexing. LightRAG uses an LLM per query to generate keywords. — [Analytics Vidhya: LightRAG](https://www.analyticsvidhya.com/blog/2025/01/lightrag/)
- Microsoft's **LazyGraphRAG** (Nov 2024) defers LLM summarization to query time. Microsoft reports indexing cost equal to vector RAG, about 0.1% of full GraphRAG. — [Microsoft Research blog: LazyGraphRAG](https://www.microsoft.com/en-us/research/blog/lazygraphrag-setting-a-new-standard-for-quality-and-cost/) (not re-fetched)
- **Graphiti** is an open-source temporal KG engine used by Zep.
  - It has an MCP server and runs on Neo4j, FalkorDB, or Kuzu.
  - It invalidates outdated edges instead of summarizing over them.
  - Zep self-reports LoCoMo 94.7% with 87 ms p50 (May 2026).
  - Sources: [vectorize.io: Zep vs Cognee](https://vectorize.io/articles/zep-vs-cognee); [graphiti-core on PyPI](https://pypi.org/project/graphiti-core/0.9.5); [cognee.ai: Cognee vs Zep](https://www.cognee.ai/cognee-vs-zep) (vendor sources)
- **Cognee** is an open-source memory engine. It can run fully local, has an MCP server for Claude Code, ingests files, DBs, web, and code, and is less specialized for temporal queries. No dedicated Obsidian integration was found. — [cognee.ai migration guide](https://www.cognee.ai/migrating-from-zep); [vectorize.io](https://vectorize.io/articles/zep-vs-cognee)
- **Basic Memory** builds a "persistent semantic graph" stored as plain Markdown (observations and relations written in the notes) and integrates directly with Obsidian. — [basic-memory GitHub mirror](https://github.com/mcp-research/basicmachines-co__basic-memory)

### Inferences
- For 1k–50k personal notes, LLM entity extraction over the whole vault means hours of LLM calls. It also requires re-extraction as notes change, and produces a second graph that competes with the user's own links.
- The better-value pattern:
  - Hybrid retrieve top-k.
  - Expand by wikilinks, backlinks, and shared tags (1 hop), via Obsidian's metadata cache, Dataview-style parsing, or a simple link table in SQLite.
  - Rerank.
- Consider LightRAG or LazyGraphRAG only for a large PDF/research subcorpus where "what are the themes across everything" questions matter.
- Graphiti/Cognee fit the "agent memory written back into the vault" use case, not indexing an existing vault.

### Gaps
- No published benchmark found specifically on personal-notes corpora comparing KG approaches vs hybrid search, or measuring the value of using Obsidian's wikilink graph for retrieval.
- Current maturity and release dates for Microsoft GraphRAG (v2.x?) and LightRAG in late 2026 were not verified.

---

## Q5. Turnkey tools: maturity in 2026

### Takeaway
The clear 2026 winner for the Claude/agent workflow is **qmd**: local, MIT-licensed, about 31k stars, hybrid search + reranking, MCP server, Claude Code plugin, and referenced in Karpathy's LLM-Wiki gist. Inside Obsidian, **Smart Connections** (v4, local embeddings, related-notes UX) and **Copilot** (Vault QA, embeddings now optional) remain the main plugins. **Basic Memory** is the active MCP-native "AI writes Markdown memory into your vault" option. **Khoj** is self-host-only after its cloud shut down in April 2026. Reor's status is unknown.

### Cited Findings
- **qmd** (tobi/qmd):
  - About **30.8k stars, 1.9k forks, MIT**, TypeScript.
  - Install with `npm install -g @tobilu/qmd` (or bun).
  - The MCP server runs over stdio or HTTP (`qmd mcp --http` keeps models warm) and exposes `query`, `get`, `multi_get`, `status`, and `metadata`.
  - Default models: embeddinggemma-300M (Q8, ~300MB), qwen3-reranker-0.6b (~640MB), and a qmd-query-expansion-1.7B fine-tune (~1.1GB), all cached in `~/.cache/qmd/models/`. Qwen3-Embedding can be swapped in for multilingual/CJK use, which requires a re-embed.
  - Commands: `qmd collection add`, `qmd update` (reports new/updated/unchanged/removed), `qmd embed` (incremental; `-f` forces a full re-embed). An optional per-collection pre-update command (e.g., `git pull`) is supported.
  - No file-watch mode is documented.
  - Source: [tobi/qmd README](https://github.com/tobi/qmd)
- qmd is installable as a Claude Code plugin via `claude plugin marketplace add tobi/qmd`. A v2.1.0 README was referenced as of 2026-05-09. — [jc-aiwiki: qmd hybrid search](https://jc-aiwiki.pages.dev/claude-ai/qmd-hybrid-search); [heyuan110: qmd as agent memory](https://www.heyuan110.com/posts/ai/2026-03-25-qmd-local-search-ai-agent-memory) (secondary; star counts across aggregators are inconsistent, so the GitHub figure above is preferred)
- **Smart Connections**: v4, 5.5k stars. Uses a local embedding model by default, an index in `.smart-env/`, and event-driven sync. API chat features moved to "Smart Chat Pro". The "Smart Context" feature assembles connected notes for pasting into an LLM. No MCP server is mentioned in the README. — [brianpetro/obsidian-smart-connections](https://github.com/brianpetro/obsidian-smart-connections)
- **Obsidian Copilot**: Vault QA with optional semantic index, and vault search works without an index. — [community.obsidian.md/plugins/copilot](https://community.obsidian.md/plugins/copilot)
- **Khoj**: hosted cloud service shut down **15 April 2026**. Self-hosting via Docker/pip is now the only option, and the repo is still active (not archived). — [promptquorum: Khoj Review 2026](https://www.promptquorum.com/power-local-llm/khoj-ai-second-brain-review) (secondary)
- **Basic Memory**: AGPL-3.0, about 3.6k stars, active. A v0.22.1 release is cited for 13 Jun 2026. It is local-first with optional paid cloud sync, and stores knowledge as Markdown that integrates with Obsidian. — [mnemoverse: 13 Memory MCP Servers Compared 2026](https://mnemoverse.com/docs/library/memory-mcp-servers-compared); [top-mcps: Basic Memory](https://top-mcps.com/mcp/basic-memory); [sylvainleroy.com (Aug 2026)](https://sylvainleroy.com/2026/08/basic-memory-persistent-ai-memory-obsidian/)
- **Obsidian ecosystem**: Obsidian shipped an official CLI. As of late Oct 2026 there is still **no official Obsidian MCP**, and the community `jacksteamdev/obsidian-mcp-tools` was reportedly archived. — [GitHub issue maxkuminov/obsidian-mcp #345](https://github.com/maxkuminov/obsidian-mcp/issues/345)
- **AnythingLLM**: listed as Active/MIT in one review table, with no primary confirmation. — [mnemoverse](https://mnemoverse.com/docs/library/memory-mcp-servers-compared) (weak)

### Inferences
Maturity tiers for an Obsidian + Claude user in Nov 2026:
- **Production-ready, local, agent-friendly:** qmd (search) and Basic Memory (memory writing). Both are file-first: the vault stays the source of truth.
- **In-Obsidian UX:** Smart Connections (related notes) and Copilot (chat with vault). Their indexes are private to the plugins and not easily reused by external agents.
- **Heavier platforms:** Khoj, AnythingLLM, Open WebUI Knowledge. These suit multi-source or multi-user setups and are overkill for one vault plus Claude.

### Gaps
- **Reor:** no 2026 information found. It may be dormant; unverified.
- **Open WebUI Knowledge** and **AnythingLLM**: no 2026 primary sources checked for how they handle Markdown vault ingestion or sync.
- qmd's exact latest version and release date were not visible on the GitHub page (the Releases section was empty).

---

## Q6. "Do you even need a vector DB?": agentic grep vs RAG vs long context, and where the crossovers are

### Takeaway
Rough crossover points:
- **Under ~200k tokens** (roughly 150k words, a few hundred notes): skip retrieval and stuff the whole vault into context with caching. Anthropic recommends exactly this.
- **Up to ~400k words / a few hundred well-indexed pages:** an agent navigating an LLM-maintained `index.md` plus grep works. This is Karpathy's LLM-Wiki report.
- **Thousands to 50k notes plus PDFs:** grep alone starts to miss paraphrased or conceptual matches, and context rot penalizes dumping. Add a local hybrid index (qmd-style) as a **tool the agent calls alongside grep**, not as a replacement.

### Cited Findings
- Anthropic: "If your knowledge base is smaller than 200,000 tokens," include the whole thing in the prompt instead of RAG, using prompt caching. — [Anthropic: Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval)
- **Boris Cherny (Claude Code)** said early Claude Code used RAG with a local vector DB, but "agentic search generally works better". He called the evidence "mostly vibes" plus some internal benchmarks. A second reason was avoiding the indexing step and its security downsides, at the cost of latency and tokens. — [OfficeChai](https://officechai.com/ai/claude-researcher-explains-how-agentic-search-performed-better-than-rag-for-code-generation/); [engineered.at summary](https://engineered.at/articles/building-claude-code-with-boris-cherny) (secondary reports of a podcast and X post)
- **Karpathy's "LLM Wiki" / LLM Knowledge Base** (April 2026):
  - Raw sources go into a folder. The LLM (Claude Code) compiles and maintains interlinked Markdown pages, with Obsidian as the viewer.
  - A reported domain wiki of about 100 articles / **400,000 words** works with **no vector DB, embeddings, or chunking**: the LLM navigates via its `index.md` catalog and summaries, plus an append-only `log.md`.
  - The gist lists **qmd as optional tooling** once the wiki grows.
  - Write-ups disagree on when to add search: about 100 pages, about 200+ pages, or "hundreds of pages".
  - Sources: [noqta.tn](https://noqta.tn/en/news/karpathy-llm-knowledge-bases-personal-wiki-2026); [spokes-wiki: LLM Wiki gist summary](https://spokes-wiki.pages.dev/research-wiki/llm-wiki-gist); [starmorph guide](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide) (all secondary; the original gist was not fetched)
- One analysis warns that if the LLM-maintained index drifts, the wiki becomes misleading rather than merely incomplete. — [spokes-wiki](https://spokes-wiki.pages.dev/research-wiki/llm-wiki-gist)
- **Context rot (Chroma Research):** all 18 frontier models tested degraded as input length grew, even well below their maximum windows.
  - Semantically similar distractors hurt beyond what length alone explains.
  - Lower query–answer similarity made degradation appear sooner.
  - Sources: [W&B summary](https://wandb.ai/byyoung3/ml-news/reports/Chroma-Research-Warns-of-Context-Rot-as-LLMs-Falter-with-Long-Inputs--VmlldzoxMzczMjQ4MQ); [particula.tech](https://particula.tech/blog/chroma-context-rot-long-context-degradation) (primary at trychroma.com/research/context-rot, not fetched). Sources disagree on the tested range (1K–1M vs 32K–1M).
- The AI Engineer Europe 2026 talk "RAG is dead, right?" frames agentic search as an agent progressively finding and reasoning over context with tools, a superset that can include retrieval tools. — [ai.engineer talk](https://www.ai.engineer/talks/UM6sFg_jdlE-rag-is-dead-right-kuba-rogut)
- A counter-framing argues that "RAG vs agentic search" is the wrong debate, and that the representation of the corpus (structure, summaries, indexes) matters more. — [dev.to: The Representation Problem](https://dev.to/chen115y/the-representation-problem-why-rag-vs-agentic-search-is-the-wrong-debate-4j8f)

### Inferences
- **Corpus size math** (assumes about 300–500 words per note and ~1.3 tokens per word; these are estimates, not sourced):

  | Notes | Approx. words | Approx. tokens | Fits in context? |
  |---|---|---|---|
  | 1k | 0.3–0.5M | 0.4–0.65M | Exceeds 200k, but within 1M windows. Subject to context rot and expensive per query. |
  | 50k | 15–25M | 20–33M | Far beyond any context window. |

- So long context alone only works for small vaults or a pre-filtered subset.
- **Why agentic grep wins for code but is weaker for notes:**
  - Code has precise identifiers. Personal notes are paraphrastic, written over years with inconsistent vocabulary, so lexical grep misses "the note where I talked about burnout" when the note says "exhausted, need a break".
  - Semantic or hybrid search closes that gap. The best design keeps grep/glob and file reading as the agent's primary tools and adds a hybrid `search` tool (qmd) for conceptual recall.
- **Crossover heuristics for a single user:**
  - Under ~150k words: no infra. Use Claude with the folder in context or Projects.
  - ~150k–500k words with good structure (MOCs/index notes): agentic grep plus an index.md is sufficient. Add qmd if recall frustrates.
  - Over ~500k words, or thousands of notes, or many PDFs: run a hybrid local index (qmd) exposed via MCP. Agentic grep remains a complementary tool.
- The index's latency and token savings matter more as the agent runs more often (e.g., daily automated workflows).

### Gaps
- No controlled benchmark found comparing agentic grep vs hybrid RAG vs long-context specifically on personal-note corpora. The crossovers above are synthesized heuristics.
- Karpathy's original gist and post were not fetched directly, so the exact wording of the 400k-word figure is unverified.
- The current 1M-context pricing and availability for Claude/Gemini/GPT models as of Nov 2026 was not checked (out of scope; an adjacent researcher may cover it).

---

## Q7. Keeping the index in sync with an evolving vault, and exposing it via MCP

### Takeaway
Use content-hash-based incremental re-indexing (only changed or new files are re-chunked and re-embedded, and deleted files are removed), triggered by a file watcher or a cheap periodic/agent-initiated `update`. Keep the index outside synced folders. Expose it as an MCP server with a small tool surface (search/query, get, multi_get, status) so Claude Code, Claude Desktop, and other agents share one index.

### Cited Findings
- qmd's sync model:
  - `qmd update` rescans and classifies files as new, updated, unchanged, or removed. `qmd embed` embeds what is needed, and `-f` forces a full re-embed.
  - An optional per-collection pre-update command (e.g., `git pull`) is supported.
  - Switching embedding models requires a full re-embed.
  - **No built-in file watcher is documented.**
  - Source: [tobi/qmd README](https://github.com/tobi/qmd)
- qmd MCP runs over stdio by default. `qmd mcp --http` keeps models loaded between requests, avoiding cold-start model loads. — [tobi/qmd README](https://github.com/tobi/qmd)
- Smart Connections syncs by listening to Obsidian vault events and re-imports sources after model changes. The `.smart-env/` folder should be excluded from third-party sync. — [obsidian-smart-connections README](https://github.com/brianpetro/obsidian-smart-connections)
- Copilot requires a manual "Force Re-index" after major changes and a rebuild on embedding-model change. — [apiyi docs](https://docs.apiyi.com/en/scenarios/chat/obsidian-copilot)
- Platform-specific binary indexes break under iCloud/Git sync and must be regenerated per device. — [promptquorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026) (secondary)
- No official Obsidian MCP exists as of late Oct 2026. Community MCPs vary, and at least one prominent one is archived. — [obsidian-mcp issue #345](https://github.com/maxkuminov/obsidian-mcp/issues/345)
- Basic Memory exposes the vault via MCP and writes structured Markdown back into it. — [top-mcps: Basic Memory](https://top-mcps.com/mcp/basic-memory)

### Inferences
- **Recommended build on macOS / Apple Silicon:**
  1. **Install qmd** (`npm i -g @tobilu/qmd`), then `qmd collection add ~/Vault`, then `qmd update && qmd embed`.
  2. **Add the MCP server** to Claude Code / Claude Desktop (`qmd mcp`, or `--http` as a launchd agent so models stay warm).
  3. **Keep it fresh:**
     - A launchd `WatchPaths` job or `fswatch -o ~/Vault | xargs -n1 -I{} qmd update` with debounce (e.g., 30–60 s), then `qmd embed`.
     - Or a nightly cron.
     - Or have the agent call `qmd update` at session start (cheap, since unchanged files are skipped).
  4. **Store the index outside the vault** (qmd already uses `~/.cache/qmd`), so iCloud/Obsidian Sync never touches it. Treat it as disposable and rebuild on a new machine.
  5. **PDFs:** convert to Markdown first (e.g., a sidecar `.md` per PDF in an excluded folder), then index those. qmd indexes Markdown, and PDF support is not documented in the README.
  6. **Keep agentic grep as well.** Claude Code's built-in Grep/Glob/Read over the vault plus qmd's `query` tool gives both exact and conceptual recall.
- **DIY alternative**, if you want custom chunking or frontmatter filters: a Python or TS script with watchdog/chokidar, then heading-aware chunking with title/heading/frontmatter prefix, then EmbeddingGemma or Qwen3-Embedding via Ollama/MLX, then SQLite (FTS5 + sqlite-vec) or LanceDB keyed by `(path, chunk_idx, content_hash)`. Expose it with a ~100-line FastMCP server providing `search(query, filters)`, `get(path)`, and `related(path)` (wikilink plus vector neighbors).
- Pin the embedding model and version in index metadata, so a model change triggers a full rebuild rather than silently mixing vector spaces.

### Gaps
- Did not verify whether qmd added a `watch` mode after the README snapshot, or whether it natively ingests PDFs.
- No primary source checked for PDF-to-Markdown converters' quality in 2026 (e.g., docling, marker, MinerU); flag for whoever covers ingestion.
- No primary benchmark found for incremental re-embed latency on Apple Silicon.
