# Spec: KBIndex (index.sqlite, reconcile, full-text search)

Status: **FTS half built** (phase 0, spike B). Plan refs: §4.6, §4.7, §6.2, §8 spike B.

## Inputs
- A `Vault`, its `VaultPolicy`, and an `index.sqlite` URL (default `~/Library/Application Support/granite/<vault-id>/index.sqlite`).
- For `update(paths:)`: vault-relative paths reported by a watcher.

## Outputs
- `Indexer.reconcile()` / `update(paths:)` → `ReconcileReport` (scanned, parsed, touched, removed, unchanged, seconds).
- `IndexDatabase.search(_:options:)` → best block per note, bm25-ranked, with snippet, heading path, line, block id.
- `titles(matching:)`, `backlinks(to:)`, `unresolvedLinks()`, `stats()`.

## Behaviour
- **Disposable.** `PRAGMA user_version` = `IndexDatabase.schemaVersion`. Any other version: files deleted, schema recreated.
- **Change detection.** mtime + size first; then SHA-256. Same hash → `touched` (mtime updated, no re-parse).
- **Stable rowids.** A re-parsed note is updated in place, so other notes' resolved links stay attached. Its incoming links are un-resolved and re-resolved, in case its name or aliases changed.
- **Parallel parse.** `TaskGroup` over all cores; writes in transactions of 800 notes.
- **Link resolution order** (after every reconcile/update): self-link → exact vault path → file name (shortest path wins) → path suffix (`folder/name`) → alias. Unresolved links are kept with `dst NULL`.
- **Search.** Plain words become quoted FTS5 terms (operators in user input are neutralized); the last word becomes a prefix once it has 3+ characters. FTS5 ranks first and only the top 200+ rowids are joined; if filters leave too few results, an exhaustive query runs.
- **Evidence scope.** `AI/` is excluded unless `includeAI`. `maxLabel` hides notes stricter than the caller's route (e.g. `.cloud` for MCP). `folders` restricts by prefix.

## Schema (v1)
`objects`, `aliases`, `props` (EAV, list items exploded), `tags`, `links` (typed, with anchors, embed flag, syntax, line), `blocks`, `blocks_fts` (external-content FTS5, `unicode61 remove_diacritics 2`, kept in sync by triggers), `meta`. Not yet: `chunks`, `chunks_vec`, `embed_meta`, `claims_x`, `proposals`, `prompts`, `zotero_*` (added with their features; a version bump rebuilds).

## Files
`Packages/KBIndex/Sources/KBIndex/{IndexDatabase,Indexer,Queries}.swift`; tests in `Packages/KBIndex/Tests/KBIndexTests/`.

## Done when
- [x] Tests green: resolution, typed backlinks, evidence scope, labels, folders, incremental edit/touch/delete, rename, watcher paths, schema rebuild, 1k-fixture recall@10 ≥ 0.9.
- [x] Spike B FTS gates on the 50k fixture (see `docs/decisions/0001-spike-b-fts-index.md`).
- [ ] FSEvents watcher with persisted event ID (day 9).
- [ ] sqlite-vec + embeddings + hybrid/RRF + rerank (spike B part 2).
