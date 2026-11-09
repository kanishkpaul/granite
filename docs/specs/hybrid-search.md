# Spec: hybrid search (chunks, embeddings, RRF, rerank)

Status: **built** (spike B part 2, decision 0007). Plan refs: §4.6, §6.1, §6.2, §8 spike B.

## Inputs
- Indexed notes (`KBIndex`), an `Embedder` and optionally a `Reranker` (protocols in `KBIndex`; MLX implementations in `KBAIMLX`).
- A query plus `HybridOptions`: mode (`bm25`, `vector`, `hybrid`), limit, candidates, rerank top-N, abstention threshold, evidence scope (`includeAI`), `maxLabel`, folders.

## Outputs
- `HybridResult`: best chunk per note with path, heading path, chunk text, BM25 rank, vector rank, fused score, rerank score; `abstained`; per-stage timings.

## Pipeline
1. **Chunks** (KBCore `Chunker`, version 1): heading-aware, about 900 tokens, a new chunk at every `#`/`##`, small sections merged, blocks never split. Prefix `Title > Heading` is prepended for embedding. Written with the note by the indexer (schema v2).
2. **Embedding** (`EmbeddingJob`): every chunk without a vector, batched by length, normalized float32 BLOBs in `chunk_vectors`. Notes labelled `none` are never embedded. Vectors from another model, dimension or chunker version are cleared, never mixed (`embed_meta`). Edited notes lose their chunks' vectors and are re-embedded on the next run.
3. **Retrieve**: FTS5 BM25 → chunk ranks (best block per chunk) ∥ exact cosine over all vectors (`VectorIndex`, Accelerate, reloads on a generation counter); both filtered by label, evidence scope and folder.
4. **Fuse**: reciprocal rank fusion, k = 60.
5. **Rerank** the top 30 (Qwen3-Reranker with a notes-specific instruction); abstain if the best score is below the threshold.
6. **Group**: best chunk per note.

## Models (KBAIMLX)
- Embedder: `mlx-community/embeddinggemma-300m-8bit`, EmbeddingGemma query/document prompts, Matryoshka truncation 768 → 512.
- Reranker: `mlx-community/Qwen3-Reranker-0.6B-4bit`.
- Build with `xcodebuild` (SwiftPM cannot compile MLX's Metal shaders): `Tools/granite-ml` (`embed`, `search`, `bench`).

## Tests
`swift test` in KBIndex with a fake synonym-aware embedder and fake reranker: embedding once, `none` skipped, model change clears, edits re-embed, vectors find what keywords miss, fusion rewards agreement, reranker reorders, abstention, BM25-only fallback without an embedder.

## Done when
- [x] Pipeline built and tested without MLX.
- [x] Real models: paraphrase queries recall 1.0 where BM25 finds nothing.
- [x] Spike B gates measured (decision 0007).
- [ ] Abstention threshold tuned on the personal re-find set (`.granite/eval/retrieval.jsonl`).
- [ ] App and `granite-mcp` use hybrid search (phase 2; both need an xcodebuild-built MLX path).
