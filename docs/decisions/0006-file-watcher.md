# 0006: File watcher (FSEvents + persisted event ID)

Date: 2026-11-09 · Status: **accepted** · Plan: §4.7, §13 day 9

## What was built
`KBIndex.FileWatcher` (FSEvents → `AsyncStream`), `KBIndex.VaultSync` (applies batches, persists the event ID in `index.sqlite`), `granite-cli watch`, and the app's `VaultStore` keeping the index live and reloading the open note when it changes on disk. Spec: `docs/specs/watcher.md`.

## Results (50k-note fixture, Apple M5)
| Check | Target | Measured |
|---|---|---|
| External edit → searchable | < 1 s (plan day 9) | **18–23 ms** over 10 edits |
| One-file update, total work | — | **40–70 ms** (was 560 ms before scoping link resolution) |
| Restart after changes made while closed | replay, no vault walk | replayed from the stored event ID; no full reconcile |
| Tests with real FSEvents | — | create, edit, delete, file rename, folder rename, hidden folders ignored, replay while stopped, database-UUID mismatch → reconcile |

## Decisions
1. **One `DispatchQueue`, by exception.** FSEvents only delivers callbacks on a dispatch queue or run loop. A private serial queue is used solely as the callback queue and yields into an `AsyncStream`; CLAUDE.md records the exception.
2. **The event ID lives in `index.sqlite`**, next to the data it describes. A rebuilt index has no ID, so it reconciles; the FSEvents database UUID is stored too, so a reset volume history forces a reconcile.
3. **Persist after applying**, so a crash replays a batch rather than losing it.
4. **Folder events update the subtree** (indexed paths under it + `.md` files now on disk), which handles folder renames without a full walk.
5. **Incremental link resolution is scoped.** Only links from changed notes, and unresolved links whose target matches a changed note's old or new name, path or alias, are re-resolved. Full resolution still runs on every reconcile.
6. **Match FSEvents paths with `realpath(3)`.** Foundation's `resolvingSymlinksInPath()` strips a leading `/private`, while FSEvents reports `/private/var/…`; the first version silently dropped every event in temp folders.

## Open
- Policy reload when `.granite/policy.yaml` changes (hidden folder, so the watcher ignores it today).
- The editor's keep-mine / take-theirs banner when the open note changes on disk while it has unsaved edits (today: the disk version loads).
