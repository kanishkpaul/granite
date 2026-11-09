# Spec: FileWatcher and VaultSync (KBIndex)

Status: **built**. Plan refs: §4.7, §10 (external writers), §13 day 9.

## Inputs
- A vault root, its `IndexDatabase` and `Indexer`.
- File-system changes from any writer: granite, git, Claude Code and other agents, Finder, Obsidian.

## Outputs
- `FileWatcher`: an `AsyncStream<WatchBatch>` of vault-relative paths (files and directories) plus flags: `needsRescan`, and the batch's last FSEvents event ID.
- `VaultSync`: keeps the index current, persists `(device UUID, last event ID)` in `index.sqlite`'s `meta` table, and reports each applied batch (`SyncUpdate`: changed paths, report, whether it was a full reconcile).

## Behaviour
- **Start.** If `meta` holds an event ID for the same FSEvents database (device UUID matches), the stream starts `since` that ID, so changes made while granite was closed replay, and no stat walk is needed. Otherwise (first run, rebuilt index, FSEvents database reset): full `reconcile()`, then watch from now.
- **Coalescing.** FSEvents latency 0.2 s; paths within a batch are deduplicated.
- **Files.** `.md` paths outside hidden folders go to `Indexer.update(paths:)`, which re-parses only if the hash changed (so granite's own saves cost a hash check) and removes files that no longer exist.
- **Directories.** A created, removed or renamed directory triggers a subtree update: every indexed path under it plus every `.md` file now on disk under it.
- **Rescan.** `MustScanSubDirs`, dropped events, event-ID wrap or a root change → full `reconcile()`.
- **Persisted ID** is written only after the batch is applied, so a crash replays it rather than losing it.
- **Threading.** The FSEvents callback runs on one private serial `DispatchQueue` (the CLAUDE.md exception) and only yields into the `AsyncStream`; all work happens in actors.

## Files
`Packages/KBIndex/Sources/KBIndex/{FileWatcher,VaultSync}.swift`, tests in `Packages/KBIndex/Tests/KBIndexTests/WatcherTests.swift`; `granite-cli watch`; app: `VaultStore` runs a `VaultSync` and reloads the open note when it changes on disk.

## Done when
- [x] Tests with real FSEvents: create, edit, delete, rename a file, rename a folder, replay changes made while stopped, rescan after an FSEvents database mismatch.
- [x] Plan gate "an external edit updates granite within 1 s": 18–23 ms on the 50k fixture (decision 0006).
