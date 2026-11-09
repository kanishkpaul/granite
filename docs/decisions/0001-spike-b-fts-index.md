# 0001: Spike B, part 1 (FTS index) passes its gates

Date: 2026-11-09 · Status: **accepted** · Plan: §8 spike B, §12 research gap 2

## Context
Spike B asks whether GRDB + SQLite FTS5 can index and search a 50k-note vault fast enough, before vectors are added. Part 2 (sqlite-vec, EmbeddingGemma, reranker) is still open.

## What was built
`KBCore` parser, `KBIndex` (GRDB 7.12.0, system SQLite with FTS5), `KBTestSupport` fixture generator, `granite-cli`. Release build, Apple M5 (4P + 6E cores), 16 GB, macOS 27.0.1.

## Fixture
`granite-cli fixture --notes 50000 --seed 42`: 151 MiB of Markdown across the plan's folders; 463,510 blocks, 256,527 links (25,655 deliberately unresolved), 15,757 distinct tags. Generated in 12.6 s.

## Results

| Gate | Target | Measured | Pass |
|---|---|---|---|
| FTS-only cold index | < 2 min | **19.9 s** (161 MB peak RSS; index 345 MB) | yes |
| Warm-launch reconcile (nothing changed) | < 3 s | **0.9–1.1 s** | yes |
| Incremental: 100 edited notes | — | 1.09 s (dominated by the stat walk) | — |
| FTS query p95 (Phase 1 gate) | < 50 ms | **1.8 ms** p95, 0.6 ms p50 (300 queries × 5) | yes |
| 3-letter prefix that matches much of the vault (`gra*`) | — | ~160 ms p95 | note |

Synthetic recall@5 = 1.00, MRR 0.99. This only proves the plumbing: synthetic queries are drawn from the target note's own words. It says nothing about retrieval quality on your vault; the personal re-find set (§11) is the real measure.

## Decisions
1. **Keep GRDB + system SQLite for FTS.** No custom SQLite build is needed until sqlite-vec arrives; then evaluate `grdb-vector` vs. the brute-force BLOB fallback in part 2.
2. **Rank inside FTS5, join afterwards.** The first version joined every matching block before ranking: 335 ms p50 on 1–2 letter prefixes. Ranking the top 200 rowids inside the virtual table and joining only those fixed it; an exhaustive query runs only when filters starve the candidate list.
3. **Prefix-expand only words of 3+ characters.** One- and two-letter prefixes add cost and no useful ranking.
4. **Stable rowids on re-parse.** Notes are updated in place; incoming links are un-resolved and re-resolved so alias or rename changes never leave stale edges.

## Follow-ups
- If broad prefix queries matter for search-as-you-type, try FTS5 `prefix='3'` and measure index growth.
- The stat walk (~0.9 s at 50k) bounds warm launch. A persisted FSEvents event ID can skip it on most launches.
- Part 2: sqlite-vec packaging, MLX embeddings, hybrid RRF, reranker latency.
