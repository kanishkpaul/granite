# AI/ML layer for a native macOS (Swift, Apple Silicon) personal knowledge-base app — state as of November 2026

Scope: embeddings, retrieval, LLM reasoning, agents/tool use, MCP, evaluation, privacy/security. Source of truth = Markdown files + SQLite index. Background from earlier research (not re-verified here): hybrid BM25 + vector + rerank beats plain vector search (Anthropic contextual retrieval: −35% / −49% / −67% retrieval failures — [Anthropic](https://www.anthropic.com/news/contextual-retrieval)); qmd ([tobi/qmd](https://github.com/tobi/qmd)) is the local reference design; wikilinks act as the graph (no GraphRAG); provenance is enforced; AI writes only to a derived layer.

Important dating note: WWDC26 (June 2026) changed the picture a lot. The OS 27 releases (macOS 27, shipped in autumn 2026) add a pluggable `LanguageModel` protocol to Apple's Foundation Models framework, a Private Cloud Compute (PCC) server model, and first-party adapters for MLX, Core AI and Claude. Many 2025 blog posts describing "Foundation Models = 4K-context on-device only" are now partly out of date.

---

## 1. On-device LLMs: Apple Foundation Models, MLX Swift, Core ML/Core AI, NaturalLanguage, llama.cpp

### Takeaway
On macOS 27, Apple's Foundation Models framework is the natural **orchestration API**, not just one model. `LanguageModelSession` with `@Generable` guided generation and `Tool` calling can now drive (a) the built-in on-device model (small context: 4K, or 8K on newer devices), (b) Apple's PCC server model (32K context, reasoning, free under 2M downloads, per-user daily quota), (c) any MLX model through `MLXLanguageModel`, and (d) Claude through Anthropic's Swift package. The on-device system model fits classification, tagging and short rewrites. Long-document synthesis needs PCC, a local MLX model (Qwen3/Gemma 4 class, 4–8B), or Claude. MLX Swift is the fastest local runtime on M-series Macs in 2026 benchmarks, usually 1.5–2× llama.cpp on decode.

### Cited Findings
**Apple Foundation Models framework**
- The on-device model's context window covers instructions, prompts, tool definitions/calls and responses combined. Exceeding it throws `exceededContextWindowSize`. Tool use counts against the window — [InfoQ](https://infoq.com/news/2026/03/apple-foundation-models-context); [atelier-socle guide](https://www.atelier-socle.com/en/articles/foundation-models-api-guide)
- Feb 2026 (macOS 26.4): new on-device model with better instruction-following and tool calling; less over-blocking from guardrails; `SystemLanguageModel.tokenCount(for:)` and `contextSize` APIs; Xcode `#Playground` shows usage of the "4,096 tokens in the available context window". Apple warns that the model changes with OS updates, so prompts need retesting per OS version — [Apple: Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels.md)
- June 2026 (OS 27): a newer on-device model; the **`LanguageModel` protocol** to "use any large language model — server or on-device — with the Foundation Models framework"; **`PrivateCloudComputeLanguageModel`** for "more reasoning capabilities and a larger context size"; image input with Vision tools (`OCRTool`, `BarcodeReaderTool`); `GenerationOptions.ToolCallingMode` for per-request tool control; `LanguageModelSession.DynamicProfile` for "multimodal agentic" experiences; an updated Instruments template showing latency, prompts, tool calls and token usage; the open-source `foundation-models-utilities`, plus `CoreAILanguageModel` (apple/coreai-models) and `MLXLanguageModel` (ml-explore/mlx-swift-lm) adapters — [Apple: Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels.md)
- March 2026: Foundation Models SDK for Python gives access to the on-device model, which helps with offline eval scripting — [Apple: Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels.md)
- WWDC26 session 319: PCC model context = 32,768 tokens; reasoning levels `.light/.moderate/.deep` via `ContextOptions(reasoningLevel:)`, and reasoning tokens count against `contextSize`; on-device context is 4K in 26.0 and **8K on newer devices in 27.0**; on-device has no reasoning. PCC needs a **managed entitlement**, has a **per-user daily quota** tied to iCloud (higher with iCloud+), does not work offline, and is **free for apps with under 2M downloads** (no API keys, no per-token billing). Quota APIs are `quotaUsage.status`, `isLimitReached` and `limitIncreaseSuggestion`. Request data is not retained after the response. `@Generable`, tools and `respond` signatures are the same across both models — [WWDC Notes, session 319](https://wwdcnotes.com/documentation/wwdc26-319-build-with-the-new-apple-foundation-model-on-private-cloud-compute/); [Apple docs: PCC contextSize](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/contextsize.md)
- Sources disagree on the OS 27 on-device context. WWDC notes say "4K (8K on newer devices in 27.0)"; one third-party write-up says 8,192 with no device caveat — [search summary of dev.to WWDC26 posts](https://dev.to/hariharanjagan/whats-new-in-apples-foundation-models-framework-at-wwdc-2026-5227). Treat it as device-dependent and read `contextSize` at runtime.
- Measured on a Mac: the Foundation Models on-device model decodes at about 85.2 tok/s, TTFT 269 ms, with about 27 MB in-process memory because the model runs in a system process. Decode figures are ±20% because token counts were estimated, and the row is undated — [apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench)

**MLX / MLX Swift**
- `ml-explore/mlx-swift-lm` is at 3.32.x (main = 3.x major with breaking changes). It ships `MLXEmbedders` (encoder/embedding models) and a `MLXFoundationModels` bridge: `MLXLanguageModel` plugs into `LanguageModelSession` and declares capabilities `.guidedGeneration`, `.toolCalling`, `.vision` and `.reasoning`. `@Generable` output is grammar-constrained. The bridge needs the OS 27 SDK. It depends on swift-huggingface ≥0.9 and swift-transformers ≥1.3 — [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm)
- The repo advises checking the model factories/registries for supported embedding architectures rather than relying on static lists. Community docs name BGE, Nomic and MiniLM as embedder examples — [mlx-swift-lm via search](https://swiftpackageregistry.com/ml-explore/mlx-swift-lm); [community skill doc](https://clawhub.ai/ronaldmannak/skills/mlx-swift-lm)
- M4 Max decode benchmarks (2026): Qwen3-8B MLX ≈ 90–98 tok/s, prefill ≈ 825 tok/s; Qwen3-4B ≈ 146 tok/s, prefill ≈ 1,500 tok/s; Qwen3-0.6B ≈ 430–556 tok/s; gpt-oss-20b (MoE) 100 tok/s on MLX; Gemma 4 E2B 178–185 tok/s (MLX) vs 119–127 (llama.cpp); Gemma 4 E4B 113.5 (MLX) vs 80.5 (llama.cpp); Nemotron-3 Nano 30B-A3B 159.7 tok/s (MLX) vs 86.2 (llama.cpp). Core ML was much slower for LLM decode (e.g. Gemma 4 E2B 32.5 tok/s, TTFT 525 ms). The new Apple "Core AI" runtime is roughly at MLX parity (Qwen3-8B 94.1 vs 90.0) — [apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench)
- Memory on M4 Max: Gemma 4 E2B MLX 2.8 GB, E4B 4.4 GB; Qwen 3.5 2B 1.2 GB. llama.cpp TTFT was lower than MLX for small models (Qwen 3.5 2B 29 ms vs 42 ms) — [apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench)
- Caveat from the benchmark author: cross-session numbers are not directly comparable, and quantization differs between runtimes — [apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench)

**NaturalLanguage framework**
- No independent retrieval benchmark of `NLContextualEmbedding` exists. A Swift package built on it self-reports P@1 1.00 / MRR 0.83 on an unspecified set, with 1–15 ms search over 50–1,000 items (768-d) on an M3 MacBook Air (unverified) — [NaturalLanguageEmbeddings](https://swiftpackageregistry.com/buh/NaturalLanguageEmbeddings). Another package calls static `NLEmbedding` "fast but weaker on paraphrase and nuance than transformer models" — [dyerlab/Linguistics](https://github.com/dyerlab/Linguistics)

### Inferences
- **Recommended on-device tiering:** (1) `SystemLanguageModel` for micro-tasks such as tag suggestion, title generation, "is this a question?" classification, and short `@Generable` extractions. These are zero download, ~85 tok/s, near-zero app memory, and fit within 4–8K. (2) An MLX model (e.g. Qwen3-4B/8B or Gemma 4 E4B, 4-bit) via `MLXLanguageModel` for private-folder synthesis that needs more than 8K context or must never leave the device. It is an optional download of several GB, and the user should opt in. (3) PCC for medium-difficulty reasoning on non-private notes, at no cost to the developer. (4) Claude for frontier quality. Because all four sit behind the same `LanguageModelSession` / `Tool` / `@Generable` surface, the routing policy can be one enum switch rather than four code paths.
- Write prompts and tools once against `LanguageModelSession`. The Instruments template and `tokenCount(for:)` then give per-route token accounting for free.
- PCC's per-user daily quota means it cannot be the backbone of nightly batch jobs. Use it for interactive features and degrade gracefully when the quota runs out (the persistent UI state that Apple recommends).
- Skip llama.cpp unless a model only exists in GGUF. MLX is faster for decode on Mac, and llama.cpp's main advantage is mmap'd memory and a slightly lower TTFT.
- NLEmbedding / NLContextualEmbedding: use at most as a zero-download fallback or for language ID. They are not a primary retriever.

### Gaps
- No official Apple table of on-device model context per device/OS; read `contextSize` at runtime.
- PCC terms above 2M downloads, and whether PCC is allowed for Mac apps distributed outside the App Store, were not found.
- `DynamicProfile` semantics were not documented in the sources I reached.
- No benchmark of the Foundation Models tool-calling *accuracy* on macOS 27 was found.

---

## 2. On-device embedding and reranking models, and how to run them from Swift

### Takeaway
Good 2026 local choices: **EmbeddingGemma (308M, <200 MB quantized, 2K context, multilingual)** or **Qwen3-Embedding-0.6B (instruction-aware, 32K context)** for dense vectors, plus **Qwen3-Reranker-0.6B** (or bge-reranker) as a cross-encoder over the top 20–50 hybrid candidates. All run via MLX Swift (`MLXEmbedders`, or the `mlx_embeddings` Swift lib for Qwen3). Hard, independent Mac latency numbers are scarce. Benchmark on the target corpus and hardware.

### Cited Findings
- EmbeddingGemma: 308M parameters, designed for on-device / low-latency use, 2K context window, under 200 MB RAM when quantized — [HF blog](https://huggingface.co/blog/embeddinggemma); [paper](https://arxiv.org/html/2509.20354v3). MTEB Multilingual v2 mean 61.15 per a third-party table — [datalearner](https://www.datalearner.com/ai-models/pretrained-models/embeddinggemma-300m)
- A vendor test reports ~24–26 ms per query for an MLX "EmbeddingGemma 2" build on M1 Ultra. The model name could not be verified. On a 30-query test, adding Qwen3-Reranker-4B lifted Recall@5 from 92.22% to 95.56% (weak, vendor-run evidence) — [regolo.ai](https://regolo.ai/embeddinggemma-2-vs-qwen3-embedding-benchmarks.md)
- Qwen3-Embedding-0.6B pre-allocates its full 32,768-token KV cache under Ollama, using about 5.8 GB on M1 Ultra. Cap the sequence length when running it yourself — [regolo.ai](https://regolo.ai/embeddinggemma-2-vs-qwen3-embedding-benchmarks.md)
- MLX 8-bit Qwen3-Embedding-0.6B weights exist on HF — [majentik/Qwen3-Embedding-0.6B-MLX-8bit](https://huggingface.co/majentik/Qwen3-Embedding-0.6B-MLX-8bit). The Swift library `mlx_embeddings` supports Qwen3 with instruction-based embeddings and needs macOS 14+ and Swift 6 — [mzbac/mlx.embeddings](https://github.com/mzbac/mlx.embeddings)
- MLX Swift weights for an "EmbeddingGemma 2" are published (pinned to MLX Swift 0.32.3 and swift-transformers 1.3.0), with no perf numbers — [HF](https://huggingface.co/Nurymanau/EmbeddingGemma-2-MLX-Swift)
- A self-reported claim says MLX Qwen3-Embedding-0.6B is about 5× faster than Ollama's version on an unspecified Mac — [PyPI roocode-code-indexer-macos](https://pypi.org/project/roocode-code-indexer-macos/). A Python `embed-rerank` server exists for MLX embedding + rerank — [PyPI embed-rerank](https://pypi.org/project/embed-rerank/)
- `MLXEmbedders` (in mlx-swift-lm) loads embedders via `loadModelContainer(configuration:)`, e.g. `mlx-community/bge-small-en-v1.5-mlx` — [community docs via search](https://mcp.directory/skills/swift-mlx-lm); [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm)
- Contextual retrieval (prepending a doc-level context sentence to each chunk before embedding and BM25) plus rerank produced the −67% failure figure — [Anthropic](https://www.anthropic.com/news/contextual-retrieval)

### Inferences
- **Default stack:** SQLite FTS5 (BM25) + `sqlite-vec` (or an in-memory flat index; a personal corpus of fewer than 200K chunks fits brute-force cosine in milliseconds on M-series) + EmbeddingGemma at 768-d with Matryoshka truncation to 256/512 to save space + Qwen3-Reranker-0.6B over the top ~30. Fuse with RRF (Reciprocal Rank Fusion), as qmd does.
- Generate the contextual-retrieval chunk prefix with the on-device Foundation model. It is a short, bounded summarization task that fits in 4K. This avoids paying Claude for it and keeps private notes local. Batch-index at idle using `BGTaskScheduler`/`NSBackgroundActivityScheduler`.
- Store `embedding_model_id + dim + chunker_version` per vector row so model upgrades trigger a background re-embed, not a corrupted index.
- If the corpus is mostly English, Qwen3-Embedding-0.6B with a task instruction is a reasonable alternative. Cap `max_length` (e.g. 1–2K) to avoid the multi-GB KV allocation.
- Reranker cost: a 0.6B cross-encoder over 30 pairs per query should take well under a second on M-series, given Qwen3-0.6B prefill of about 9K tok/s on M4 Max per the LLM bench. That is an inference from LLM prefill numbers, not a measured reranker figure.

### Gaps
- No verified Swift/MLX benchmark of Qwen3-Reranker-0.6B, and no confirmation that `MLXEmbedders` registers Qwen3-Reranker or EmbeddingGemma out of the box. A custom model class may be needed.
- No current Core ML-converted embedding model benchmarks were found. Core ML (ANE) may save power for batch indexing but was not measured for embedders.
- No head-to-head EmbeddingGemma vs Qwen3-Embedding retrieval quality on personal-notes-style data.

---

## 3. Cloud: calling Claude (and others) from Swift — SDKs, caching, tools, structured output, cost, Agent SDK subprocess, keys

### Takeaway
There is now an **official Anthropic Swift package for Foundation Models** (announced June 8, 2026, for OS 27). It plugs Claude into `LanguageModelSession` with streaming, tool calls, structured (`@Generable`) responses, and server-side web search and code execution. It is not a full Messages API client. For prompt caching, citations, batches, Files and MCP connector features, use raw HTTP (`URLSession`) against `/v1/messages` or a community client. Current prices make cloud calls cheap for single-user volumes: Sonnet 5.5 at $2/$10 per MTok with cache hits at $0.10, and Haiku 5.5 at $0.10/$0.50. Claude Code / Agent SDK can be driven as a subprocess over NDJSON `stream-json`, but that conflicts with the App Store sandbox.

### Cited Findings
**Swift access**
- Anthropic (June 8, 2026): a Swift package lets developers call Claude from Apple's Foundation Models framework on iOS/iPadOS/macOS/visionOS/watchOS 27. It handles streaming, tool calls and structured responses, and offers web search and code execution. Users sign in with an Anthropic API key — [Claude blog](https://www.claude.com/blog/claude-for-foundation-models)
- The repo is `anthropics/ClaudeForFoundationModels` (Apache 2.0, beta, from: "0.1.0"). It conforms Claude to the FM `LanguageModel` protocol (e.g. `ClaudeLanguageModel(... .sonnet4_6 ...)`). The README mentions a proxied auth option and App Attest client IDs, but the blog only mentions API keys, so verify — [GitHub wiki via search](https://github.com/anthropics/ClaudeForFoundationModels/wiki); [everydev summary](https://www.everydev.ai/tools/claude-for-foundation-models)
- No official general-purpose Anthropic Swift SDK for the Messages API was found. Community option: `atacan/AnthropicAPI` (generated with swift-openapi-generator, JSON + SSE streaming) — [Swift Package Registry](https://swiftpackageregistry.com/atacan/AnthropicAPI)

**Models and prices (Claude API, first-party, Nov 2026)** — [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)
| Model | Input | 5m cache write | 1h cache write | Cache hit | Output | Batch in/out |
|---|---|---|---|---|---|---|
| Claude Opus 5.5 | $4 | $5 | $8 | $0.20 | $20 | $2 / $10 |
| Claude Sonnet 5.5 | $2 | $2.50 | $4 | $0.10 | $10 | $1 / $5 |
| Claude Haiku 5.5 (≤100K prompt) | $0.10 | $0.125 | $0.20 | $0.01 | $0.50 | $0.05 / $0.25 |
| Claude Fable 5.1 (top tier) | $10 | $12.50 | $20 | $0.25 | $50 | — |
(per MTok). Cache hits on Opus 5.5 and Sonnet 5.5 cost 0.05× the input price. Batch is 50% off. US-only `inference_geo` adds a 1.1× multiplier — [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Third-party price pages from 2026 conflict and quote older models (Opus 4.8 at $5/$25, Sonnet 4.6 at $3/$15) — [finout](https://finout.io/blog/anthropic-api-pricing); [lucaberton](https://lucaberton.com/blog/claude-api-pricing-2026-fable-opus-sonnet-haiku/). Defer to the official page above.
- Prompt caching: prefix match in the order tools → system → messages, max 4 breakpoints, 5-minute TTL by default and 1-hour optional, with a model-dependent minimum prefix (512–4096 tokens). Cache writes cost 1.25× (5m) or 2× (1h). Top-level automatic caching is available. Verify hits via `usage.cache_read_input_tokens` — [Anthropic prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) (via Anthropic's Claude API reference bundled in Claude Code, cached 2026-10-06)
- Other relevant API features (same reference): structured outputs via `output_config.format` and `strict: true` tools; **citations** on `document` blocks returning `cited_text` + char/page locations (incompatible with structured outputs); Files API (GA); Message Batches; an MCP connector (`mcp_servers` + `mcp_toolset`, beta); adaptive thinking with `effort` levels; compaction for long conversations. On the newest models (Opus 5.5, Sonnet 5.5) forced `tool_choice` returns a 400 and assistant prefill is removed, so use `auto` + `strict` or structured outputs — [Anthropic docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) (via the bundled Claude API reference)

**Claude Code / Agent SDK as a subprocess**
- Community Swift wrappers drive the Claude Code CLI over NDJSON: `claude --print --output-format stream-json --verbose` emits `system/assistant/user/result/stream_event` messages. `jamesrochabrun/ClaudeCodeSDK` (macOS 13+, Swift 6) supports a headless CLI backend or the Node Agent SDK backend. `kiliczsh/claude-agents-sdk-swift` uses actors + AsyncSequence on macOS 14. These are community specs, not official — [ClaudeCodeSDK](https://github.com/jamesrochabrun/ClaudeCodeSDK); [Swift Package Index "claude"](https://swiftpackageindex.com/keywords/claude); [community protocol gist](https://gist.github.com/POWERFULMOVES/58bcadab9483bf5e633e865f131e6c25)
- The Agent SDK is "Claude Code packaged as a library" with built-in Read/Write/Edit/Bash/Grep tools, hooks, permissions, subagents and MCP. It is harness-only, so the app hosts it — [Agent SDK docs](https://code.claude.com/docs/en/agent-sdk) (via the bundled Claude API reference)

### Inferences
- **Cost per typical operation** (Sonnet 5.5, my arithmetic from the official prices):
  - "Ask my notes" RAG answer with ~8K tokens of retrieved context + ~1K system (cached) and 600 output tokens ≈ 8K×$2/M + 600×$10/M ≈ **$0.022**. On Haiku 5.5 ≈ **$0.0011**.
  - Nightly digest over 50 changed notes (~60K input, 2K output) via Batch on Sonnet 5.5 ≈ 60K×$1/M + 2K×$5/M ≈ **$0.07/night**, about $2/month.
  - Literature synthesis over 30 papers' extracted chunks (~150K input, 4K output) on Opus 5.5 ≈ $0.60 + $0.08 ≈ **$0.68**. Repeated questions over the same cached corpus drop input to $0.20/MTok (≈$0.03 per follow-up).
- Use a two-transport design: (a) `ClaudeForFoundationModels` for interactive chat/tool flows that share code with the on-device path; (b) a thin hand-written `URLSession` Messages client (SSE parsing is ~200 lines) for caching control, citations, batches and Files. A wrong method name there is easy to fix, while coverage gaps in the FM adapter are not.
- Keys: store the user's API key in the Keychain (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synchronizable), and never in UserDefaults or the vault folder. Prefer the user's own key (BYOK) for a personal tool. A proxy is only needed for a commercial hosted plan.
- Claude Code subprocess: workable for a **Developer ID–distributed** (non-App-Store) app. Spawning a user-installed `claude` binary from a sandboxed App Store app is generally blocked by sandbox exec rules. A more robust integration is the reverse direction: expose the knowledge base as an MCP server (§4) and let the user's Claude Code/Desktop call it.
- Other providers (OpenAI, Gemini) can be added behind the same `LanguageModel` protocol, since Apple designed it to be provider-agnostic. No first-party OpenAI/Google Swift FM adapters were verified.

### Gaps
- ClaudeForFoundationModels' coverage of prompt caching, citations and batches is unconfirmed. The blog doesn't mention caching.
- Exact `claude` CLI flags/protocol stability for Nov 2026 were not verified against official docs.
- No official Anthropic guidance on Keychain storage for Mac apps was found; the advice above is standard Apple practice, not sourced here.

---

## 4. MCP: the app as an MCP server (and client)

### Takeaway
The official `modelcontextprotocol/swift-sdk` (≈0.11.x, MCP spec 2025-11-25, Swift 6, macOS 13+) now ships **server-side HTTP transports** (stateless and stateful/SSE) as well as stdio. A Mac app can therefore host an MCP server in-process on localhost, or ship a tiny stdio helper binary, so Claude Desktop / Claude Code can search the vault. The app can also be an MCP client, or pass MCP servers to Claude via the API's MCP connector.

### Cited Findings
- swift-sdk implements MCP spec **2025-11-25**. Transports: `StdioTransport`, `HTTPClientTransport` (Streamable HTTP), **`StatelessHTTPServerTransport`**, **`StatefulHTTPServerTransport`** (sessions + SSE for server-initiated messages), `InMemoryTransport`, and `NetworkTransport` (Apple Network framework). Handlers are registered with `server.withMethodHandler(ListTools/CallTool/ListResources/ReadResource/ResourceSubscribe/ListPrompts/GetPrompt...)`. Requires Swift 6.0+ and macOS 13+. The install snippet shows `from: "0.11.0"` — [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)
- The README says nothing about App Sandbox — [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)
- The Claude API MCP connector needs both `mcp_servers=[{type:"url",...}]` and `tools=[{type:"mcp_toolset",...}]` with beta `mcp-client-2025-11-20`. It only reaches URL servers, not local stdio ones — [Anthropic docs](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector) (via the bundled Claude API reference)

### Inferences
- **Recommended shape:** a small, signed **stdio helper executable** embedded in the app bundle (`Contents/MacOS/strata-mcp`). Claude Desktop / Code launch it per their config. It talks to the main app over XPC or reads the SQLite index read-only (WAL mode allows concurrent readers). This avoids opening a network port. Offer a localhost `StatefulHTTPServerTransport` as an opt-in alternative, bound to 127.0.0.1 with a per-install bearer token.
- Tool surface (read-mostly, qmd-like): `search(query, mode: hybrid|bm25|vector, folder?, k)`, `get_note(path|id, range?)`, `get_backlinks(id)`, `list_recent(since)`, `get_citations(zotero_key)`. Write tools are limited to `propose_change(note_id, diff, rationale)` and `create_derived_note(...)`, which land in the proposal queue with `origin: ai` and are never applied directly. Expose notes as MCP **resources** (`note://id`) so clients can attach them.
- Enforce per-folder routing at the MCP boundary as well. Folders marked `private` are excluded from MCP results by default, because the MCP client (Claude Desktop) sends content to the cloud.
- As an MCP client (in-app agent calling external servers such as Zotero or web fetch), use the same swift-sdk client with stdio or HTTP. Treat every MCP tool result as untrusted input (§7).

### Gaps
- No found guidance on swift-sdk under the App Store sandbox (e.g. whether Claude Desktop can launch a helper inside a sandboxed app bundle). This needs a prototype.
- The latest swift-sdk release tag was not confirmed (registry showed 0.8.2 from May 2025; the README shows 0.11.0).

---

## 5. Agent features that compound — how to implement each with guardrails

### Takeaway
Build every feature as **a pipeline that writes proposals, not edits**. Retrieval first (hybrid + rerank); the model generates with **structured output that carries chunk IDs**; a deterministic Swift verifier checks each citation's quoted text against the source chunk; the result lands in a derived-layer file or the proposal queue with a provenance stamp. Batch-API or on-device models handle nightly jobs. Learning-sensitive features (spaced retrieval, Socratic partner) should ask before telling.

### Cited Findings
- Claude citations return `cited_text` plus character/page locations for `document` blocks, which makes script verification straightforward. They cannot be combined with structured output in the same request — [Anthropic docs](https://platform.claude.com/docs/en/build-with-claude/citations) (via the bundled Claude API reference)
- Foundation Models `@Generable` gives grammar-constrained typed outputs on-device and through the MLX and Claude adapters — [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm); [Claude blog](https://www.claude.com/blog/claude-for-foundation-models)
- Batch API at 50% off suits nightly asynchronous jobs — [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Anthropic's example use case: a journaling app generates prompts on-device and then asks Claude to find themes across months of entries — [Claude blog](https://www.claude.com/blog/claude-for-foundation-models)

### Inferences (implementation recipes)
- **Common guardrail substrate:** a SQLite `proposals` table (id, kind, target_note, diff/patch, rationale, citations JSON, model_id, route, prompt_hash, created_at, status). Derived notes are written under `/_derived/` with front matter `origin: ai`, `model`, `generated_at` and `sources: [note_id#chunk]`. Accepting a proposal flips the touched spans to `ai-accepted`. A **citation verifier** checks that every `[[note#^block]]` or quoted span exists and that the quote matches the source after normalization (exact or ≥0.9 token overlap). Anything that fails verification is dropped or flagged and never shown as fact.
- **Nightly digest:** a `NSBackgroundActivityScheduler` job diffs notes changed since the last run (git-style hashes in SQLite), clusters them by embedding, and summarizes each cluster with citations. Use on-device/MLX for private folders, and Batch Sonnet/Haiku 5.5 for the rest. Output is one derived note per day. Include "open questions you wrote" rather than conclusions.
- **Link suggestions:** for each new or edited note, take the top-k semantically similar notes that are not already wikilinked (vector + BM25 on titles/aliases), rerank them, then use a cheap on-device `@Generable` call {target, reason, anchor_text} to justify each link. Proposals show as inline ghost links. Precision matters more than recall, so show at most 3 and log accept/reject to tune thresholds.
- **Contradiction detection:** extract atomic claims from human-origin notes with structured output: {claim, polarity, entity, date, chunk_id}. Index the claims and, for claim pairs with high similarity and opposite polarity or differing values, run an NLI-style check (cloud model for quality). Surface each pair with both citations and ask the user which belief is current. Never auto-resolve.
- **Literature synthesis with citations:** retrieve over Zotero-derived source notes (`origin: source`), send them as `document` blocks with citations enabled (Claude), and verify every citation by script. Synthesize into `/_derived/synthesis/<topic>.md`. Each paragraph must cite, and uncited sentences are flagged. Cache the corpus prefix for follow-up questions.
- **Spaced retrieval prompts:** generate question/answer cards from human notes on-device. Schedule with FSRS (Free Spaced Repetition Scheduler) or SM-2 in SQLite. Show the question first and grade the user's recall before revealing. This follows the "passive delegation harms learning" finding from the background research.
- **Belief diff over time:** snapshot extracted claims per note version (from file history or git). Diff the claim sets per topic per month and render "you used to hold X (date, citation), now Y". Only report changes that are present in human-origin text.
- **Socratic thinking partner:** a system prompt that constrains the model to questions and counter-examples drawn from the user's own notes (retrieval tool only, no web), plus a "tell me" escape hatch that the user must invoke explicitly. Log which mode was used.
- **Agent loop runtime:** use `LanguageModelSession` with app-defined `Tool`s (search, get_note, get_backlinks, propose_change) for in-app agents. Use the Claude Messages API with strict tools for multi-step cloud runs, capped by `effort` and task budgets. No tool has direct file-write capability.

### Gaps
- I found no published evaluations of these specific PKM features (link suggestion precision, contradiction detection accuracy) on personal corpora. Thresholds must be tuned empirically.
- The Anthropic Jan 2026 learning RCT is from background research and was not re-fetched here.

---

## 6. Evaluation: measuring retrieval quality and AI usefulness on a personal corpus

### Takeaway
Use small, cheap, continuously updated evals. Build a **"re-find" set** of 50–200 (query → known note/chunk) pairs, mined from the user's real searches and clicks plus synthetic questions generated from notes. Report Recall@5/10, MRR (Mean Reciprocal Rank) and nDCG@10 for each pipeline variant (BM25 / vector / hybrid / +rerank / +contextual prefix). Measure AI usefulness with behavioral signals: proposal accept/edit/reject rates and citation-verification pass rate.

### Cited Findings
- Anthropic's contextual retrieval work reports retrieval failure rate as 1 − recall@20 and shows gains stacking from contextual embeddings, contextual BM25 and reranking — [Anthropic](https://www.anthropic.com/news/contextual-retrieval)
- A small 30-query test was enough to show a reranker effect (Recall@5 92.2% → 95.6%), but sample size limits confidence — [regolo.ai](https://regolo.ai/embeddinggemma-2-vs-qwen3-embedding-benchmarks.md)
- No independent NLContextualEmbedding retrieval benchmark exists. Self-reported P@1/MRR claims can't be verified without the eval file — [NaturalLanguageEmbeddings](https://swiftpackageregistry.com/buh/NaturalLanguageEmbeddings)
- Apple's Python FM SDK enables scripting evals against the on-device model off-app — [Apple: Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels.md)

### Inferences
- **Eval set construction:** (1) Implicit labels: log query → opened-note events locally (never uploaded). (2) Synthetic: for random chunks, have a model write a question that only that chunk answers, then hand-check a sample. (3) "Re-find tests": the user writes 20 queries from memory for notes they know exist, which is the most realistic case. Keep the set in `/_eval/retrieval.jsonl` and version it.
- Run the eval in CI and on demand in-app ("Search health" panel) whenever the embedding model, chunker or fusion weights change. Track latency p50/p95 alongside quality.
- **Generation evals:** citation precision (verified citations / total) is automatic. Faithfulness can be spot-checked with an LLM judge on a sample. For usefulness: acceptance rate per feature, edit distance of accepted proposals, and dismissals. Kill features with sustained acceptance under ~10%.
- With fewer than 200 queries, report confidence intervals or paired comparisons on the same queries rather than absolute scores.
- Learning outcomes (spaced retrieval): measure recall success on scheduled reviews rather than AI-judged "helpfulness".

### Gaps
- No 2026 sources found that specifically benchmark retrieval on personal knowledge bases. The methodology above is inferred from general IR practice and the Anthropic contextual-retrieval setup.

---

## 7. Privacy & security: prompt injection from clipped content, per-folder routing, tool sandboxing

### Takeaway
Treat every clipped web page, PDF, email and MCP/tool result as **untrusted data**. Structural defenses beat prompt-level ones. CaMeL-style separation (a planner never sees untrusted text; a quarantined model processes it without tools) reaches near-zero successful injections on AgentDojo at a utility cost (77% vs 84% tasks solved). It struggles when the actions themselves depend on untrusted content, which is common in a notes app. The practical pattern is to make tools that touch untrusted content read-only or proposal-only, to never auto-execute side effects, and to enforce routing by folder sensitivity in code, not in prompts.

### Cited Findings
- CaMeL: a privileged LLM plans without seeing untrusted data, and a quarantined LLM parses untrusted data without tool access. It reduces successful prompt injections "to zero in most cases" and solves 77% of AgentDojo tasks with provable security vs 84% undefended. It requires no model changes — [CaMeL paper](https://arxiv.org/pdf/2503.18813); [Simon Willison](https://simonw.substack.com/p/camel-offers-a-promising-new-direction)
- Limits: when the needed actions depend on untrusted data ("do what the email says"), the planner can't plan without reading it. Side-channel leaks remain. A 2026 enterprise follow-up cites overhead, policy management and interpreter language as hurdles. Layering with model-level defenses is recommended — [aktagon summary, Jul 2026](https://signals.aktagon.com/articles/2026/07/camel-defeating-prompt-injection-attacks-in-llm-agents-through-capability-based-security/); [themoonlight review](https://www.themoonlight.io/review/operationalizing-camel-strengthening-llm-defenses-for-enterprise-deployment)
- PCC: request data is not stored or retained after the response — [WWDC Notes 319](https://wwdcnotes.com/documentation/wwdc26-319-build-with-the-new-apple-foundation-model-on-private-cloud-compute/)
- The Claude API offers mid-conversation `system` role messages as the "prompt-injection-safe operator channel", and US-only `inference_geo` at 1.1× — [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing); prompt-caching docs via the bundled Claude API reference

### Inferences
- **Sensitivity labels per folder/note** (front matter `ai: local | pcc | cloud | none`, inherited from the folder) are checked by a `ModelRouter` before any context assembly. Retrieved chunks from a `local` note make the whole request local-only. Taint propagates: a derived note built from private sources inherits the strictest label. The MCP server applies the same filter.
- **Injection hygiene for clipped content:** store clips with `origin: source` and a `trust: untrusted` flag. When they are passed to a model, wrap them in clearly delimited data blocks and keep instructions in the system/operator channel. Strip hidden text (white-on-white text, zero-width characters, HTML comments) at clip time. Never let content from an untrusted chunk trigger a tool call with side effects. In agent loops, any `propose_change` derived from untrusted content goes to human review with the triggering source highlighted.
- **Exfiltration guard:** cloud-bound agents get no web-fetch tool when private-labeled content is in context. Rendered Markdown in AI output must not auto-load remote images or links, since that is a classic exfil channel. Show URLs as plain text until clicked.
- **Tool sandboxing:** agent tools are Swift functions with typed arguments and no shell. File access is limited to the vault plus `_derived`, and writes only go through the proposal queue. If the Claude Code subprocess is offered, run it with a restrictive permission mode and the vault mounted read-only, or prefer the MCP-server direction.
- Log every model call (route, model, token counts, note IDs included, and a prompt hash, not the content) to a local audit table so the user can see what left the device.

### Gaps
- No 2026 sources document injection defenses specifically for PKM/RAG note apps. Recommendations are inferred from the general agent-security literature.
- No data was found on how well the on-device Apple model resists injection.

---

## 8. Overall: what architecture should the AI layer use? (synthesis)

### Takeaway
A three-tier, router-centered design behind Apple's Foundation Models `LanguageModelSession` abstraction. Local hybrid retrieval: SQLite FTS5 + vectors + MLX reranker. Model routes chosen by sensitivity and difficulty: on-device Apple model → local MLX model → PCC → Claude (Haiku/Sonnet/Opus 5.5). A proposal queue with provenance and script-verified citations. The vault is exposed outward through an MCP server.

### Cited Findings
- The FM `LanguageModel` protocol unifies on-device, PCC, MLX, Core AI and Claude models under one session/tool/guided-generation API — [Apple: Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels.md); [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm); [Claude blog](https://www.claude.com/blog/claude-for-foundation-models)
- MLX is the fastest general local runtime on M-series Macs in 2026 benchmarks — [apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench)
- MCP swift-sdk supports both server and client roles with stdio and HTTP server transports — [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)

### Inferences
- **Components:** `Indexer` (file watcher → chunker → contextual prefix via on-device FM → EmbeddingGemma/Qwen3-Emb via MLX → SQLite FTS5 + vec) · `Retriever` (BM25 + vector → RRF → Qwen3-Reranker → wikilink neighborhood expansion) · `ModelRouter` (sensitivity label × task difficulty × quota/cost → FM system model / MLXLanguageModel / PCC / Claude via FM adapter or raw Messages client) · `ToolKit` (search, get_note, backlinks, propose_change, all typed Swift) · `ProposalQueue` + `ProvenanceStamper` + `CitationVerifier` · `Scheduler` (nightly jobs with Batch API) · `MCPServer` (stdio helper + optional localhost HTTP) · `EvalHarness` (re-find set, metrics dashboard) · `AuditLog`.
- **Minimum viable sequence:** (1) FTS5 + EmbeddingGemma hybrid search with a re-find eval; (2) the reranker; (3) MCP server (read-only), which gives immediate leverage from Claude Desktop/Code; (4) on-device link suggestions + proposal queue; (5) Claude-backed synthesis with verified citations; (6) nightly digest, contradiction detection, belief diff and spaced retrieval.
- Requiring macOS 27 brings PCC, MLX FM bridging, Claude FM integration and 8K on-device context. Supporting macOS 26 means hand-rolling the MLX and Claude paths and living with 4K on-device context. Decide this early.

### Gaps
- Unverified: App Store sandbox compatibility for the embedded MCP helper and the Claude Code subprocess; PCC entitlement eligibility for this app category; ClaudeForFoundationModels' feature coverage (caching, citations).
