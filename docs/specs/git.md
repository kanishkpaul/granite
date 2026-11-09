# Spec: git auto-commit and deletion alarm (KBGit + app)

Status: **built** (phase 1, item 2). Plan refs: §10, research report 02 (safety net, deletion alarm).

## Inputs
- The open vault, if it is a git repository (a `.git` folder or a `.git` file pointing to a separate git dir, as report 02 recommends for iCloud vaults).
- Change notifications from `VaultSync`, and app quit.

## Outputs
- Commits on the current branch, message `auto: 12 files changed (3 added, 8 modified, 1 deleted)`, author from the repo's git config (a `granite` identity only if none is set).
- `git push` after each commit when a remote is configured. Failures (offline, auth) are reported, never retried in a loop, and never prompt (`GIT_TERMINAL_PROMPT=0`, ssh `BatchMode=yes`).
- The alarm state: paused with a reason, shown in the app and as a notification.

## Behaviour
- **When.** 5 minutes after the last vault change (each change restarts the timer), and on quit.
- **What.** Everything git would add, respecting the vault's `.gitignore`. `Initialize` writes the plan's `.gitignore` (`.obsidian/workspace*.json`, `.obsidian/cache`, `.trash/`, `.DS_Store`) and a first commit; granite never runs `git init` unasked.
- **Deletion alarm.** Before staging, look at the pending changes. If more than 20 files would be deleted, or any `.md` file is 0 bytes, commit nothing, leave the index untouched, and raise the alarm (evicted iCloud files and runaway agents both look like this). The user reviews, then chooses "Commit anyway" (one commit with the deletions) or restores files with git.
- **Never collide with other git users.** Skip a round while `index.lock` exists or a merge, rebase, cherry-pick or revert is in progress.
- Not a repository → auto-commit is off and Settings offers "Initialize git".

## Files
`Packages/KBGit/` (`GitService`, `GitRunner`), `App/Capture/AutoCommitter.swift` (timer, quit hook, alarm notification, Commit Anyway), menu bar and Settings sections, `granite-cli git status|commit|push|init`. `GRANITE_AUTOCOMMIT_DELAY` (seconds) shortens the 5-minute wait for testing.

## Done when
- [x] 13 tests against real temporary repositories: commit summary, nothing-to-commit, folder renames are not deletions, alarm on > 20 deletions and on 0-byte notes (index and hand-staged work untouched), commit-anyway, `.gitignore` respected, lock and merge in progress skipped, separate git dir, push to a bare remote (upstream set on first push), push failure reported, no remote.
- [x] App smoke test: a URL capture into a git vault was committed automatically by the watcher → AutoCommitter path; quit stayed responsive.
- [ ] Restore drill (you, plan §10): restore one note from git and one from Time Machine.
