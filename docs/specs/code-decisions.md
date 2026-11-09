# Spec: code-decision records

Status: **built**. Plan refs: §4.4 (`decision`, `domain: code`, `repo`, `commits`), §7 idea 8, §8 phase 4.

## Inputs
- Repositories you add in Settings → Code (stored in `.granite/repos.json`, versioned with the vault).
- Each repo's `docs/adr/`, `doc/adr/`, `adr/`, `docs/decisions/`, `decisions/`, `docs/architecture/decisions/` Markdown files and its agent memory files (`CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`, `GEMINI.md`).
- Its last 300 commits on the checked-out branch.

## Outputs
- `Code/<repo>.md` hub (`type: project`, `kind: repo`): your description, plus a managed region (path, remote, branch, scan time, imported sources, recent commits) refreshed each scan.
- `Code/<repo>/sources/<file>.md` (`type: source`, `kind: adr | agent-memory`, `origin: source`, `file`, `sha`): the file's text in a managed region, rewritten only when the file changes.
- `Granite-Decision: <id or title>` trailers: the commit's sha is added to that decision note's `commits` list (and `repo` set if missing). Unknown references are reported.
- Decision-like commits without a trailer (subjects like "switch to", "migrate", "drop", "in favour of", matched on word boundaries; fixes, merges, reverts and bumps excluded): up to 10 per scan become `decision` proposals that create `Code/<repo>/<subject>.md` (`type: decision`, `domain: code`, `status: proposed`, `commits`) with Context filled in and **Why** left for you.

## Rules
- Scans run on adding a repo, from ⌘K "Scan code repositories", Settings "Scan Now", and nightly after the digest.
- Only the vault is written; repositories are read (git log, files).
- A new `decision` proposal kind creates the stub; nothing is recorded until you accept it.

## Files
`Packages/KBCode`, `Packages/KBGit` (`commits`, trailers, remote, branch), `KBCore.ProposalKind.decision`, `App/Code/Code.swift`; tests `CodeScannerTests` (real temp repo: imports, trailer links, unknown trailers, candidates, rescan keeps your text and refreshes changed files; stubs; registry), `GitServiceTests.commitsAndTrailers`.

## Done when
- [x] Tests above.
- [x] Scanned this repository from a scratch vault: 8 decision records and CLAUDE.md imported, hub written.
- [ ] Judge by whether you reopen the records (the plan calls this a design hypothesis).
