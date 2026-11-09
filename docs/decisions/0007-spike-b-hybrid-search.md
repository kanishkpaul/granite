# 0007: Spike B part 2, local hybrid search (EmbeddingGemma + Qwen3 reranker)

Date: 2026-11-09 · Status: **accepted** · Plan: §6.1, §6.2, §8 spike B, §12 gaps 2–3

## What was built
Chunks (schema v2), `EmbeddingJob`, an exact-cosine `VectorIndex`, and `HybridSearcher` (BM25 ∥ vectors → RRF → rerank → abstain) in `KBIndex`, behind `Embedder`/`Reranker` protocols and tested with fakes. MLX implementations in `KBAIMLX`; `Tools/granite-ml` (`embed`, `search`, `bench`). Spec: `docs/specs/hybrid-search.md`.

## Results (Apple M5, Release build)
| Gate / question | Target | Measured |
|---|---|---|
| MLXEmbedders loads EmbeddingGemma; reranker support (gap 3) | works | yes: `embeddinggemma-300m-8bit` and `Qwen3-Reranker-0.6B-4bit` load (first download about 100 s each) |
| Meaning, not keywords | — | 10 paraphrase queries over real English notes: vector and hybrid recall@5 = **1.0**, BM25 = 0 (no shared words) |
| Hybrid + rerank latency | p95 < 800 ms | **p50 221 ms, p95 358 ms** (rerank of 30 candidates ≈ 195 ms; query embed ≈ 20 ms) |
| Embedding throughput | record chunks/s | **28.5 chunks/s** after batching by length (11.1 before) |
| Full embed overnight-able | yes | 125k fixture chunks ≈ 70 min at that rate; a real vault of a few thousand chunks takes minutes |
| Cold index with chunking, 50k notes | < 2 min | 27 s (chunking adds 7 s) |

Not measured, by choice: vector search over all 125k fixture chunks (the run was stopped at ~29k vectors). Exact cosine is one matrix–vector product, so it grows linearly; the plan's own estimate is milliseconds below 200k chunks.

## Findings
1. **MLX needs `xcodebuild`.** SwiftPM cannot compile MLX's Metal shaders, so MLX code lives in its own package (`KBAIMLX`) and tool (`granite-ml`), and everything else stays on `swift test`.
2. **Batch by length.** A batch is padded to its longest chunk; sorting each window of 512 pending chunks by length made embedding 2.6× faster.
3. **The reranker needs a notes instruction.** With Qwen3's default (web-search) instruction, correct but indirect notes scored as low as 0.004. A notes-specific instruction raised weak matches (0.080 → 0.637 for the same query) while unanswerable questions stayed at 0.000.
4. **Abstention threshold is not set.** Correct answers ranged 0.009–0.89, unanswerable 0.000. Ten queries can't fix a threshold; tune it on the personal re-find set (plan §11).
5. **sqlite-vec is not needed yet.** Exact cosine over float32 BLOBs (Accelerate) is the plan's fallback and is fast enough; revisit above ~200k chunks.

## Decisions
- Keep EmbeddingGemma 300M (8-bit, 768 → 512 Matryoshka) and Qwen3-Reranker 0.6B (4-bit) as the local models.
- Keep embedding on the Mac. A remote bulk-embedding route (e.g. Hugging Face ZeroGPU) is possible later for `cloud`-labelled notes only, if a real vault's first embed is too slow.
- Phase 2 wires hybrid search into the app and `granite-mcp`; both then need the xcodebuild-built MLX path.
