# Free Sync + Version History for an Obsidian Vault (macOS-centric, Nov 2026)

Research date: 2026-11-03. Release dates and repo status were pulled live from the GitHub API on that date (`api.github.com/repos/<repo>/releases`). Snapshot of project health:

| Project | Latest release | Last push | Open issues | Status |
|---|---|---|---|---|
| Vinzent03/obsidian-git | 2.42.0 (2026-10-18); 2.41.0 (2026-10-01) | 2026-11-03 | ~94 | Active |
| vrtmrz/obsidian-livesync (Self-hosted LiveSync) | 1.0.44 (2026-11-01) | 2026-11-03 | ~253 | Very active |
| remotely-save/remotely-save | 0.5.25 (2024-10-20) | 2024-11-10 | ~231 | **Stalled ~2 years** |
| ViscousPot/GitSync (mobile git app) | v1.8.65 (2026-09-11) | 2026-10-29 | ~180 | Active |
| syncthing/syncthing | v2.1.7 (2026-10-21) | 2026-11-03 | ~398 | Active |
| syncthing/syncthing-android (official) | 1.28.1 (2024-12-03) | 2024-12-03 | n/a | **Archived** |
| researchxxl/syncthing-android ("Syncthing-Fork") | v2.1.7.0 (2026-10-21) | 2026-11-01 | n/a | Active, the current Android client |

Sources: [obsidian-git releases](https://github.com/Vinzent03/obsidian-git/releases), [obsidian-livesync releases](https://github.com/vrtmrz/obsidian-livesync/releases), [remotely-save](https://github.com/remotely-save/remotely-save), [GitSync](https://github.com/ViscousPot/GitSync), [syncthing releases](https://github.com/syncthing/syncthing/releases), [syncthing-android (archived)](https://github.com/syncthing/syncthing-android), [researchxxl/syncthing-android](https://github.com/researchxxl/syncthing-android)

## Git-based sync (Obsidian Git plugin, GitHub/GitLab/Codeberg, Working Copy, GitSync)

### Takeaway
Git is the best free option for versioning on desktop. Obsidian Git is actively maintained (2.42.0, Oct 2026) and 2.41 added in-app merge-conflict resolution. Its own docs still call the mobile build "very unstable" and advise against it. On a phone, use a dedicated git app (GitSync, free and open source on iOS/Android; or Working Copy, which is paid for push on iOS), or skip git on mobile and sync another way.

### Cited Findings
**Plugin status and mobile limitations**
- Obsidian Git v2.42.0 was released 2026-10-18, and 2.41.0 on 2026-10-01. The repo was pushed 2026-11-03 and has about 94 open issues and about 12.2k stars. — [GitHub API / repo](https://github.com/Vinzent03/obsidian-git)
- 2.41.0 "makes merge conflicts easier to resolve inside Obsidian". Source Control lists conflicted files with a count of conflict blocks. Each block offers **Keep ours / Keep theirs / Keep both**, you can resolve a whole file at once, and a merge-status button walks you to the merge commit and push. It also added opening a file's content at a specific commit from the History view. — [obsidian-git 2.41.0 release notes](https://github.com/Vinzent03/obsidian-git/releases)
- The mobile version runs on isomorphic-git, a JavaScript reimplementation of git. The README calls it "very unstable" and does not recommend it. Its limits are: no SSH auth, repo size capped by memory, no rebase merge strategy, no submodules. Depending on device RAM, Obsidian "may crash on clone/pull, create buffer overflow errors or run indefinitely", and the author says he doesn't know how to fix it. — [obsidian-git README](https://github.com/Vinzent03/obsidian-git)
- For large vaults the README suggests staging individual files and setting the auto-commit glob to "Include matches" with an empty list, so only staged files get committed. — [obsidian-git README](https://github.com/Vinzent03/obsidian-git)
- Desktop notes: Snap on Linux is unsupported and Flatpak is not recommended. Obsidian's community scorecard flags the plugin's shell execution and filesystem access, which it needs on desktop. — [obsidian-git README](https://github.com/Vinzent03/obsidian-git)

**Official setup steps (Obsidian Git docs)**
- Desktop, new repo: install git, run "Initialize a new repo", then "Commit all changes with specific message". To push, set up auth, make sure the remote repo is empty, run "Push", and enter remote name `origin` plus the URL. — [Obsidian Git docs: Getting Started](https://publish.obsidian.md/git-doc/Getting+Started)
- Desktop, existing remote: git can only clone into a new folder. Either clone into a vault subfolder and move everything (including `.git`) to the vault root, or run `git clone <url>` in a terminal. — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)
- Mobile clone via the plugin:
  1. Push and reconcile changes on all devices.
  2. Create a new vault. On iOS, do **not** choose "Store in iCloud".
  3. Create a GitHub PAT with metadata read and contents plus commit-status read/write.
  4. Enter your username and PAT under Authentication/Commit Author.
  5. Run "Git: Clone existing remote repo" with a URL ending in `.git`.
  6. Wait for the "Restart Obsidian" prompt.

  — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)
- Mobile clone via Working Copy (iOS, paid):
  1. Close Obsidian.
  2. Clone the repo in Working Copy using your username and PAT.
  3. In the Files app, copy the repo into Obsidian's vault location, using the same vault name.
  4. Enable the plugin and run Pull.

  This route assumes `.obsidian` is not committed. — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)
- GitHub requires a PAT for HTTPS. SSH isn't available on mobile. — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)
- **iCloud + git on the same vault:** the whole `.git` directory syncs to mobile and can slow Obsidian's startup. There are two documented workarounds:
  - Put the repo *above* the vault, so the vault is a subdirectory of the repo.
  - Move `.git` elsewhere and leave a `.git` *file* in the vault containing a single `gitdir: <path>` line.

  — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)

**Obsidian's official stance**
- Obsidian's help lists Git as recommended for Windows/macOS/Linux, hosted on GitHub, GitLab or self-hosted. It notes that syncing is not automatic: you must push and pull. — [Obsidian Help: Sync your notes](https://obsidian.md/help/sync-notes)
- On iOS, Working Copy "can sync vaults via Git", but it is not officially supported and some features need a paid in-app purchase. — [Obsidian Help: Sync your notes](https://obsidian.md/help/sync-notes)

**GitSync (mobile git app)**
- GitSync is a "mobile Git client for syncing a repository between remote and a local directory" that runs in the background after a one-time setup. It supports Android 5+ and iOS 13+, and ships through Google Play, the App Store, F-Droid, IzzyOnDroid and Obtainium.
  - Sync triggers: app open/close (Android only), a recurring schedule, a quick-settings tile (Android only), a home-screen widget, iOS Shortcuts/automation, and a custom intent.
  - Auth: HTTPS, SSH, and OAuth for GitHub/GitLab/Gitea.
  - It can resolve merge conflicts on mobile and retries automatically when the network returns.

  The repo topics include "obsidian". — [GitSync GitHub](https://github.com/ViscousPot/GitSync)
- The Obsidian Git README itself points mobile users to GitSync (iOS and Android) and Working Copy (iOS) as alternatives. — [obsidian-git README](https://github.com/Vinzent03/obsidian-git)

**File size limits (GitHub)**
- Git warns on files over 50 MiB. GitHub **blocks files over 100 MiB**. Repos should ideally stay under 1 GB, with under 5 GB "strongly recommended". Browser uploads max out at 25 MiB. — [GitHub Docs: About large files](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)

### Inferences
- **Recommended `.gitignore` for a vault** (standard practice, not quoted from a single source). These files churn constantly and cause meaningless conflicts:
  ```
  .obsidian/workspace.json
  .obsidian/workspace-mobile.json
  .obsidian/workspaces.json
  .obsidian/cache
  .trash/
  .DS_Store
  # optional: per-device plugin state
  .obsidian/plugins/*/data.json   # only if plugins store device-specific/secret state (e.g. Remotely Save data.json holds credentials)
  ```
  Committing the rest of `.obsidian/` (plugin list, hotkeys, appearance) is usually fine. The Working Copy route above assumes `.obsidian` isn't committed at all.
- **Merge-conflict reduction:** a `.gitattributes` line `*.md merge=union` makes git keep both sides of conflicting line edits instead of stopping on conflict markers. That suits append-heavy daily notes but can leave duplicated lines (general git knowledge; not sourced from Obsidian docs). With 2.41+, resolving conflicts in-app is now practical, so this is optional.
- **Auto-commit interval:** the plugin's "auto commit-and-sync every N minutes" setting is the main knob. On desktop, 5–15 minutes is a common balance between granular history and noise. Also enable "pull on startup" and "push after commit" so a second machine rarely diverges. (The exact setting names weren't verified against 2.42 docs in this session.)
- **Attachments:** stay under 50 MiB per file, keep large PDFs/videos out of git (add a `.gitignore` rule for an `Attachments/large/` folder), and don't add Git LFS unless needed. LFS has its own free-tier quota (not verified here), and isomorphic-git LFS support on mobile is doubtful.
- **Hosts:** GitHub, GitLab and Codeberg all offer free private repos. A private repo is *not* end-to-end encrypted, because the host can read plaintext notes. For privacy, use git-crypt or git-remote-gcrypt on desktop. Neither works with mobile isomorphic-git or most mobile git apps, so encryption effectively rules out mobile git.

### Gaps
- No 2026 benchmark numbers for Obsidian Git mobile on large vaults. The README only gives qualitative warnings.
- Current Working Copy pricing, and which features (push) require the paid unlock in 2026, were not verified.
- GitSync pricing: the README shows only sponsor links. Whether the App Store version is free or has IAPs was not verified.
- Codeberg/GitLab free-tier repo size limits and the current GitHub LFS free quota were not fetched.

## Syncthing (desktop + Android; iOS via Möbius Sync / SyncTrain)

### Takeaway
Syncthing is excellent between Macs, PCs and Android. Use the **Syncthing-Fork** (researchxxl) on Android because the official app was archived in Dec 2024. Its "staggered" versioning gives real point-in-time history, but only for changes *received from other devices*. On iOS it relies on wrapper apps (Möbius Sync, paid beyond 20 MB; or SyncTrain, free) that only sync when iOS lets them run.

### Cited Findings
- Syncthing v2.1.7 was released 2026-10-21. The official `syncthing/syncthing-android` repo is **archived**, with its last release 1.28.1 on 2024-12-03. The community fork `researchxxl/syncthing-android` ("Syncthing-Fork") released v2.1.7.0 on 2026-10-21. — [GitHub API](https://github.com/syncthing/syncthing-android), [Syncthing-Fork](https://github.com/researchxxl/syncthing-android)
- Obsidian's help confirms: "The official Android app is no longer maintained", and suggests Syncthing-Fork. Syncthing "works best when at least one device is always on". Exclude `.obsidian` if you want per-device settings, and use ignore patterns for temp/backup files. — [Obsidian Help: Sync your notes](https://obsidian.md/help/sync-notes)
- Obsidian lists Syncthing as unsupported on iOS, where plugins and wrappers are workarounds whose "results may vary". — [Obsidian Help](https://obsidian.md/help/sync-notes)

**Versioning (from the Syncthing docs)**
- Versioning is off by default and is configured per folder, per device. **It only applies to changes received from other devices. Local edits are never archived.** Versions live in `.stversions` inside the folder unless `fsPath` points elsewhere. — [Syncthing Docs: File Versioning](https://docs.syncthing.net/users/versioning.html)
- **Trash can:** keeps one copy per filename. `cleanoutDays` prunes it, and 0 means keep forever.
- **Simple:** keeps `keep` timestamped copies per file, plus `cleanoutDays`.
- **Staggered:** within the first hour, keeps one version per 30 s; within the first day, one per hour; within the first 30 days, one per day; after that, one per week until `maxAge`. The GUI shows `maxAge` in days, but the config uses seconds, and 0 means forever.
- **External:** runs a command before a file is replaced or deleted. Placeholders are `%FOLDER_PATH%`/`%FILE_PATH%`, with env-var forms added in 2.1.2.
- `cleanupIntervalS` controls how often pruning runs.

  — [Syncthing Docs: File Versioning](https://docs.syncthing.net/users/versioning.html)

**Conflicts**
- When both sides changed, the file with the **older** mtime is renamed to `<filename>.sync-conflict-<date>-<time>-<modifiedBy>.<ext>`. The conflict copy then syncs to every device. On a modify-vs-delete conflict where the delete wins, the modified file becomes the conflict copy. Syncthing writes to `.syncthing.<name>.tmp` and then renames it, so it never writes partial files in place. — [Syncthing Docs: Understanding Synchronization](https://docs.syncthing.net/users/syncing.html)

**iOS wrappers**
- Möbius Sync is free to download and free up to 20 MB. Unlimited costs $4.99 one-time (one Chinese guide says ¥38, so check the App Store). — [stephanmiller.com, updated 2026-09-25](https://www.stephanmiller.com/sync-obsidian-iphone-ipad-free/); [Obsidian forum: Syncthing + Möbius](https://forum.obsidian.md/t/sync-mac-pc-and-ios-using-syncthing-mobius-sync/72022)
- SyncTrain is free and open source with no IAPs, requires iOS 17+, and has Shortcuts integration (a "Sync for a while" action). Its developer warns against using it for backups. Both devices must be awake at the same time. — [stephanmiller.com](https://www.stephanmiller.com/sync-obsidian-iphone-ipad-free/)
- Forum users report that Möbius syncs in the background at iOS-determined intervals of about 5–15 min. Users also advise opening Möbius before Obsidian for a reliable sync. — [Obsidian forum: Syncthing + Möbius on iOS](https://forum.obsidian.md/t/syncthing-mobius-sync-on-ios/69569)
- If the Mac vault is also a git repo, add `.git` to Syncthing's ignores so git history doesn't sync to iOS. — [Obsidian forum thread](https://forum.obsidian.md/t/sync-mac-pc-and-ios-using-syncthing-mobius-sync/72022)

### Inferences
- **Suggested `.stignore` for a vault:**
  ```
  .git
  .obsidian/workspace*.json
  .trash
  .DS_Store
  ```
  Also exclude `.stversions` from any *other* backup tool if you don't want version bloat.
- Because local edits aren't versioned, Syncthing versioning on the Mac only protects against bad changes arriving *from the phone or other PC*. It does nothing if you or an AI agent on the Mac damages a file. Pair it with git or Time Machine.
- Syncthing on iOS is "eventually consistent while the app is foregrounded". Editing the same note on phone and Mac before a sync completes produces `.sync-conflict-` files that must be merged by hand.

### Gaps
- Whether Möbius Sync is still actively developed in late 2026 (last App Store update date) was not verified.
- The `maxConflicts` default was not on the fetched page.

## iCloud Drive (Mac + iPhone): reliability, evictions, and the iCloud + git hybrid

### Takeaway
iCloud is Obsidian's officially recommended free path for Mac ↔ iPhone, and the only option that runs in the background on iOS. Its failure modes are real but specific:
- evicted placeholders when "Keep Downloaded" isn't set
- "Note 2.md" duplicate conflicts
- stalled syncs with no error
- occasional unexplained empty or overwritten notes

None of these give you version history. iCloud for sync plus local git on the Mac for history is a sound hybrid, *provided `.git` is kept out of iCloud*.

### Cited Findings
- Obsidian recommends iCloud for iOS/macOS and warns that iCloud Drive on Windows "may lead to file duplication or corruption".
  - On **macOS 15+**, right-click the Obsidian folder and choose **"Keep Downloaded"**. On macOS 14 and earlier, turn off Optimize Mac Storage, which is global.
  - Store vaults **inside the Obsidian folder** in iCloud Drive (the folder with the app icon).
  - "Avoid syncing the same vault across multiple services."

  — [Obsidian Help: Sync your notes](https://obsidian.md/help/sync-notes)
- Failure modes listed in a 2026 guide:
  - **Eviction:** placeholders break search, graph and backlinks.
  - **Numbered conflict copies** ("Meeting Notes 2.md"), with no merge or prompt.
  - **Corrupted or reverted `.obsidian` JSON**, where plugins can disable themselves.
  - **Stalled sync**, pending with no error.

  The guide's mitigation: close Obsidian everywhere, let sync finish, and diff numbered copies before deleting them, since some hold unique text. — [dev.to: Obsidian iCloud Sync in 2026](https://dev.to/eristoddle/obsidian-icloud-sync-in-2026-including-the-windows-problem-4503)
- "Optimize Mac Storage can remove notes", and cloud-only placeholders can make search return incomplete results silently. No iOS method syncs continuously in the background. The guide's recommendation for a Mac user is iCloud. — [stephanmiller.com (2026-09-25)](https://www.stephanmiller.com/sync-obsidian-iphone-ipad-free/)
- Forum data-loss threads include:
  - [a note silently overwritten by another note in an iCloud vault with no other sync](https://forum.obsidian.md/t/note-content-silently-overwritten-by-another-note-icloud-vault-no-remote-sync/98672) (the thread returned 404 when fetched directly, so details are unverified)
  - [notes reverting to earlier saves](https://forum.obsidian.md/t/note-sometimes-does-not-save/18282)
  - [a note suddenly empty](https://forum.obsidian.md/t/data-loss-note-is-suddenly-empty/57356/6), where a moderator attributed it most likely to iCloud-on-Windows
  - [deleted notes not appearing in File Recovery](https://forum.obsidian.md/t/note-just-disappeared-and-closed/94908)
  - [users abandoning iCloud as unreliable](https://forum.obsidian.md/t/icloud-sync-issues/28320/41)

  No single confirmed root cause was established. — Obsidian forum (linked above)
- An HN commenter notes that on iOS "only iCloud gets to run in the background". Third-party Syncthing and git apps can't. Another moved from Syncthing to Dropbox to iCloud and finally paid for Obsidian Sync after iCloud conflicts. — [HN summary via search](https://news.ycombinator.com/item?id=34066824) (individual comment permalinks not verified)

**Git inside iCloud**
- The Obsidian Git docs warn that `.git` syncs to mobile and slows startup, and give the repo-above-vault and `gitdir:` pointer-file workarounds. — [Obsidian Git docs](https://publish.obsidian.md/git-doc/Getting+Started)
- Blog reports: iCloud syncs `.git/objects` files independently, which can leave the repo inconsistent, and it can create conflict copies like `HEAD 2` in `.git/refs/` when two machines write. One author keeps `.git` in iCloud and relies on `git fsck`. A forum user reported that after moving `.git` and writing a pointer file, the plugin complained it wasn't a valid repo. — [mandalivia: local-only git](https://mandalivia-astro.pages.dev/obsidian/tracking-obsidian-vault-changes-with-local-only-git/), [dev.to: side effect of storing a git repo in iCloud](https://dev.to/architchandra/a-side-effect-of-storing-a-git-repository-in-icloud-drive-7ed), [Obsidian forum: .git outside vault](https://forum.obsidian.md/t/obsidian-git-users-how-to-put-the-git-folder-outside-of-my-vault-to-avoid-sync-issues-with-icloud/101968)

### Inferences
- **Recommended hybrid (Mac + iPhone only):**
  1. Put the vault in `iCloud Drive/Obsidian/<Vault>` and right-click it → Keep Downloaded.
  2. Keep the git database outside iCloud: `git init --separate-git-dir ~/vault-git/<Vault>.git` run inside the vault. This writes a `.git` *file* (`gitdir: …`) into the vault.
  3. Commit from the Mac only, using a launchd job or the Obsidian Git plugin (test that the plugin recognizes the `gitdir` file; the forum reported trouble), plus a `git push` to a private remote.
  4. Never commit from the phone.

  This is "one sync service plus one versioning tool". It does not stack two sync engines, because git on a single machine does not sync anything into the vault.
- The `.git` pointer file itself syncs to the iPhone harmlessly, but iOS Obsidian with the Git plugin installed might try to use it. Keep the Git plugin disabled on mobile, or exclude it via per-device plugin settings.
- iCloud has no per-file history for Obsidian notes that is usable at scale. So with iCloud alone, the only history is Obsidian File Recovery (7 days, per device) plus Time Machine. Git closes this gap.
- Run `git status` before committing. A sudden mass deletion or 0-byte files in the diff is an early warning of an iCloud eviction or sync incident, and you can restore with `git checkout -- .`.

### Gaps
- No primary Apple documentation or reproducible root cause for silent overwrites on macOS ↔ iOS (as opposed to Windows) was found.
- No source tested whether `brctl`-reported states or the macOS 26/27 iCloud changes affect Obsidian.

## Remotely Save, Self-hosted LiveSync, and other free/self-hosted options (Nextcloud, WebDAV, S3, R2)

### Takeaway
Self-hosted LiveSync is the most actively developed free plugin (1.0.44, 2026-11-01). It supports CouchDB, S3/R2 object storage, or WebRTC peer-to-peer, all with E2EE, but it is complex and has had data-integrity bugs. Remotely Save hasn't shipped a release since Oct 2024 and should be treated as **effectively unmaintained**. It still works with S3/R2/WebDAV/Dropbox, but conflict handling in the free tier is crude (newer or larger file wins).

### Cited Findings
**Self-hosted LiveSync**
- Backends: CouchDB, S3-compatible object storage (MinIO/S3/R2), and WebRTC P2P. P2P needs no storage server but still needs a signalling relay (public or your own), and at least one device holding the data must be online. It "supports end-to-end encryption". New devices are added via a Setup URI. It requires Obsidian 1.7.2+. — [LiveSync README](https://github.com/vrtmrz/obsidian-livesync)
- Warnings: it is incompatible with Obsidian Sync. **Do not run it alongside other sync solutions, including iCloud.** Back up before installing or upgrading. — [LiveSync README](https://github.com/vrtmrz/obsidian-livesync)
- Hosting guides cover your own server, Docker, Fly.io, IBM Cloudant, and a third-party managed host (Zenith), which the project doesn't endorse. — [LiveSync README](https://github.com/vrtmrz/obsidian-livesync)
- 1.0.44 (2026-11-01) fixed files containing raw U+001F being **truncated when received through S3-compatible object storage** (#1303). Every client must update, and updating doesn't repair already-damaged copies. The release also reworked parts of the architecture, and the author asks users to report problems. — [LiveSync releases](https://github.com/vrtmrz/obsidian-livesync/releases)
- Release cadence: 1.0.42 (10-27), 1.0.43 (10-30), 1.0.44 (11-01), 2026. — [GitHub API](https://github.com/vrtmrz/obsidian-livesync/releases)

**Remotely Save**
- Free backends: S3 and S3-compatible storage (R2, B2, MinIO), Dropbox, OneDrive personal (App Folder), WebDAV (Nextcloud, Synology, InfiniCloud…), and Webdis (experimental). PRO (paid): full OneDrive, Google Drive, Box, pCloud, Yandex, Koofr, Azure, and "Smart Conflict" merging. — [remotely-save README](https://github.com/remotely-save/remotely-save)
- Encryption is optional and password-based, in "openssl / rclone crypt format". For Dropbox, OneDrive and WebDAV the vault name is not encrypted. `data.json` holds secrets. Large files (≥50 MB) may sync poorly on mobile. **Auto-sync runs only while Obsidian is open and fails silently on errors.** Config-folder sync is experimental. Files starting with `.` or `_` are excluded by default. In the free tier, conflicts keep the newer or larger file. — [remotely-save README](https://github.com/remotely-save/remotely-save)
- Last release 0.5.25 was on 2024-10-20 and the last push on 2024-11-10, with about 231 open issues. — [GitHub API](https://github.com/remotely-save/remotely-save)
- A Lemmy comment says it "has not been maintained for 2 years". The Obsidian stats tracker shows its last update as 2024-10-21. A security fork, "Remotely Sync", exists but is not backward compatible. — [Lemmy](https://lemmy.world/comment/24698409), [obsidian-stats](https://www.moritzjung.dev/obsidian-stats/plugins/remotely-save), [Remotely Secure/Sync listing](https://obsidian-plugin-directory.vercel.app/plugins/remotely-secure)

**Object storage free tier**
- Cloudflare R2 free tier: 10 GB-month of Standard storage, 1M Class A and 10M Class B operations per month, and free egress. It doesn't apply to Infrequent Access. — [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/)

**Obsidian's stance**
- On iOS, Dropbox, Google Drive, OneDrive and Syncthing are unsupported. Remotely Save and LiveSync are workarounds whose "results may vary". For OneDrive, mark the vault "Always keep on this device" and avoid Files On-Demand. — [Obsidian Help](https://obsidian.md/help/sync-notes)

### Inferences
- LiveSync with R2 or another S3 bucket plus E2EE is the most "Obsidian Sync-like" free setup: near-real-time, works on iOS while Obsidian is open, and is encrypted. The trade-offs are complexity, a database-like internal format (notes are chunked, so recovery outside the plugin is harder), and a fast release cadence that occasionally ships integrity bugs (the U+001F truncation). Pin a known-good version and keep git or Time Machine as an independent backup.
- Remotely Save on R2 or WebDAV still functions, but it is a two-year-stale plugin with silent-failure auto-sync. Don't start new setups on it. Existing users should watch for Obsidian API breakage.
- Nextcloud/WebDAV via Remotely Save means self-hosting (or a free Nextcloud provider) *plus* a stale plugin. Using Nextcloud's own desktop client on the Mac has the same mobile problem as Syncthing: no iOS vault access.
- Fly.io and IBM Cloudant appear in LiveSync's guides, but whether they still have usable **free** tiers in 2026 wasn't verified. From memory: Fly.io dropped its free allowance for new orgs around 2024, and Cloudant Lite has historically been 1 GB free. Treat both as unverified.

### Gaps
- LiveSync E2EE algorithm and key-derivation details were not on the README page fetched.
- No 2026 independent reliability study of LiveSync. The evidence is release notes and issue count only.
- Whether Remotely Save still works with current Obsidian (1.9/1.10+) was not tested.

## Version history: what actually gives point-in-time recovery?

### Takeaway
Only **git** (explicit, repo-wide, syncable history) and **Time Machine** (hourly snapshots of the whole disk on the Mac) give true vault-wide point-in-time recovery. Obsidian File Recovery is a 7-day, per-device, .md/.canvas-only safety net. Syncthing versioning only captures *incoming remote* changes. Use git as the primary history, Time Machine as the independent backup, and File Recovery as the quick undo.

### Cited Findings
- **Obsidian File Recovery:** snapshots are at least **5 minutes** apart and retained for **7 days** by default, both configurable. They are stored in Obsidian's global settings, *outside* the vault, are **not synced**, and are device-specific. Only `.md` and `.canvas` files are covered. Moving the vault without "Move vault to a different folder" can orphan the snapshots. It doesn't work under Lockdown Mode unless Obsidian is exempted. The docs say it is "not a complete backup solution". Restore via Settings → File recovery → View, with a Show changes diff. — [Obsidian Help: File recovery](https://obsidian.md/help/Plugins/File+recovery)
- **Syncthing versioning** archives only changes received from other devices, never local edits. Staggered mode thins versions to 30 s/hourly/daily/weekly tiers. — [Syncthing Docs](https://docs.syncthing.net/users/versioning.html)
- **Git:** Obsidian Git 2.41 can open a file's content at any commit from the History view. — [obsidian-git releases](https://github.com/Vinzent03/obsidian-git/releases)
- **Deleted notes can be missing from File Recovery** (a user report). — [Obsidian forum](https://forum.obsidian.md/t/note-just-disappeared-and-closed/94908)

### Inferences
| Layer | Granularity | Scope | Survives device loss | Covers attachments | Covers agent edits on Mac |
|---|---|---|---|---|---|
| File Recovery | ≥5 min, 7 days | single device, .md/.canvas | No | No | Only if made via Obsidian's editor? (snapshots are taken on Obsidian's own saves; likely misses external writes. Unverified) |
| Git (pushed) | per commit (5–15 min auto) | whole vault | Yes (remote) | Yes (<100 MiB) | Yes |
| Syncthing staggered | per incoming change | per receiving device | Partly | Yes | No (local edits) |
| Time Machine | hourly local snapshots, then daily/weekly | whole Mac | If the backup disk is separate | Yes | Yes |

- Time Machine *does* back up iCloud Drive files that are downloaded locally ("Keep Downloaded"), but not evicted placeholders. "Keep Downloaded" therefore matters for backups too. This is general macOS behaviour and wasn't verified in a source this session.
- Real recovery playbook: (1) File Recovery for "I just broke this note"; (2) `git log -p -- path/note.md` / `git checkout <sha> -- path` for anything older or vault-wide; (3) Time Machine if `.git` itself is damaged or an untracked attachment is lost.

### Gaps
- Whether File Recovery snapshots capture changes written by external processes (AI agents, scripts) rather than Obsidian's editor is not documented on the page fetched.

## AI agents (Claude Code, MCP servers) writing into the vault: making edits reviewable and reversible

### Takeaway
Treat the vault as a git repo and give the agent its own branch or worktree. Review `git diff`, then merge or discard. Several 2026 tools build UIs on that pattern, but the core workflow is plain git and needs no plugin.

### Cited Findings
- The "Code Workbench" Obsidian plugin embeds a Claude Code terminal and shows side-by-side Keep/Reject diffs of Claude's edits, plus a branch graph and inline git blame. The listing reads as self-promotion. — [community.obsidian.md: code-workbench](https://community.obsidian.md/plugins/code-workbench)
- A blogger reviews agent changes in the vault through git diff and leaves inline HTML comments as feedback. — [artemxtech substack](https://artemxtech.substack.com/p/what-changed-in-2-weeks-claude-code)
- A Claude Code + Obsidian guide recommends `.claude/settings.json` to declare safe folders, edits requiring confirmation and off-limits files, plus a `CLAUDE.md` with vault conventions. — [claudecode-lab guide](https://claudecode-lab.pages.dev/en/blog/claude-code-obsidian-integration/)
- Vaultsmith runs codex or claude in tmux and has the agent *propose* changes, applied via `vsm review` → `vsm approve` → `vsm apply`. — [Vaultsmith GitHub](https://github.com/ronut01/Vaultsmith)
- Another vault-to-code guide recommends Claude Code's `--worktree` workflow. Git worktrees share history while isolating the working directory, which keeps agent changes out of the main checkout until reviewed. — [evomap blog](https://evomap.ai/blog/obsidian-claude-code-vault-to-code-workflow)

### Inferences
- **Concrete pattern:**
  1. Commit the human state first (`git commit -am "pre-agent snapshot"`).
  2. Run the agent on `agent/<task>` (a branch) or in a worktree (`git worktree add ../vault-agent agent/<task>`) so Obsidian and the sync service never see half-finished edits.
  3. Review with `git diff main...agent/<task>`, or in Obsidian Git's Source Control view.
  4. Merge, or `git branch -D`.
- If the agent must write directly into the live vault (e.g., an MCP server pointed at the vault path), at minimum have it commit after each task with a distinctive author (`git -c user.name="claude-agent" commit …`). Then `git log --author=claude-agent` lists everything it did, and `git revert <sha>` undoes one task cleanly.
- **Sync interaction risk:** with iCloud, Syncthing or LiveSync, every agent write propagates to phones within seconds or minutes. A runaway agent that deletes or rewrites many files would be synced everywhere. With Syncthing, the *other* devices' staggered versioning would capture the prior versions, but with iCloud nothing would. Worktree isolation outside the synced folder avoids this entirely.
- Put the worktree *outside* the iCloud/Syncthing folder. Otherwise the sync engine ships the agent's scratch branch to your phone, and two copies of every note appear in the vault.
- Obsidian File Recovery likely won't capture agent edits made outside Obsidian (see the gap above), so git is the main safety net for agent changes.

### Gaps
- No primary Anthropic documentation for `--worktree` was fetched this session. The claim comes from a third-party blog.
- No source found on MCP servers that enforce git commits automatically.

## Encryption and privacy for free hosted options

### Takeaway
The free options with real E2EE are Self-hosted LiveSync (built-in E2EE across all backends) and Remotely Save (rclone-crypt format, with vault-name leakage on some backends). Syncthing has no cloud at all: it is device-to-device, and relays only see TLS traffic. Private GitHub/GitLab/Codeberg repos and iCloud (unless Advanced Data Protection is on) are readable by the provider.

### Cited Findings
- LiveSync "supports end-to-end encryption". Third-party managed hosts store your data on their servers. — [LiveSync README](https://github.com/vrtmrz/obsidian-livesync)
- Remotely Save encrypts in openssl/rclone-crypt format when a password is set. The vault name is not encrypted on Dropbox, OneDrive or WebDAV, and `data.json` contains secrets. — [remotely-save README](https://github.com/remotely-save/remotely-save)
- Syncthing syncs directly between devices without cloud storage. — [Obsidian Help](https://obsidian.md/help/sync-notes)

### Inferences
- iCloud Drive is end-to-end encrypted only if the user enables Apple's **Advanced Data Protection**. This is general Apple knowledge, not fetched this session, so verify it.
- Git hosts: private ≠ encrypted. git-crypt (per-file, transparent on desktop) or git-remote-gcrypt (whole-repo) give E2EE but break mobile git clients and web diffs. They are suitable for a Mac-only git backup, while sync to the phone goes through iCloud or Syncthing.
- Exclude `.obsidian/plugins/remotely-save/data.json` and any plugin `data.json` with API keys from git, especially on a public or shared remote.

### Gaps
- LiveSync's cipher and KDF details, and whether file paths are obfuscated, were not verified.

## What experienced users recommend, and horror-story root causes

### Takeaway
The 2025–2026 consensus:
- **Apple-only:** iCloud, plus git or Time Machine for history.
- **Mixed OS or Android:** Syncthing on desktop/Android, with an iOS wrapper if needed.
- **Technical users wanting history:** git.
- **Least hassle:** many users ultimately pay for Obsidian Sync.

Horror stories trace mostly to the following, rather than to any single tool:
- iCloud on Windows
- evicted placeholders
- two sync services on one vault
- editing on two devices before sync completed
- relying on File Recovery as a backup

### Cited Findings
- 2026 guide recommendations: **Mac → iCloud; Windows/Linux → Remotely Save with Dropbox/S3; P2P → SyncTrain; least troubleshooting → Obsidian Sync ($4–5/mo)**. — [stephanmiller.com (2026-09-25)](https://www.stephanmiller.com/sync-obsidian-iphone-ipad-free/)
  - Note: it recommends Remotely Save without mentioning that the plugin has had no release since Oct 2024.
- Obsidian officially recommends Obsidian Sync or iCloud on iOS and warns against multiple services on one vault. — [Obsidian Help](https://obsidian.md/help/sync-notes)
- HN: one commenter went Syncthing → Dropbox → iCloud → paid Obsidian Sync over iCloud conflicts. Another says iCloud "syncs in seconds" for macOS ↔ iOS. A third notes that only iCloud runs in the background on iOS. — [HN thread](https://news.ycombinator.com/item?id=34066824) (summary via search; exact comment attribution not verified)
- Horror-story root causes seen:
  - iCloud-on-Windows (moderator attribution) — [forum](https://forum.obsidian.md/t/data-loss-note-is-suddenly-empty/57356/6)
  - eviction placeholders and numbered conflict copies — [dev.to 2026](https://dev.to/eristoddle/obsidian-icloud-sync-in-2026-including-the-windows-problem-4503)
  - LiveSync S3 truncation bug (U+001F) — [LiveSync 1.0.44](https://github.com/vrtmrz/obsidian-livesync/releases)
  - Obsidian Git mobile crashes on clone/pull — [obsidian-git README](https://github.com/Vinzent03/obsidian-git)
  - Remotely Save auto-sync failing silently — [remotely-save README](https://github.com/remotely-save/remotely-save)
  - `.git` in iCloud producing `HEAD 2` ref conflicts — [mandalivia](https://mandalivia-astro.pages.dev/obsidian/tracking-obsidian-vault-changes-with-local-only-git/)

### Inferences: recommended stacks (free)
1. **Mac + iPhone (most likely for this user):**
   - Sync: iCloud Drive (`iCloud Drive/Obsidian/<Vault>`, Keep Downloaded).
   - Versioning: git with `--separate-git-dir` outside iCloud, auto-commit every 10 min from the Mac only, pushed to a private GitHub/Codeberg repo.
   - Backup: Time Machine to an external disk or NAS.
   - Quick undo: File Recovery (raise retention to 30 days).
   - Agents: run on a git worktree outside iCloud and merge after review.
   - No git plugin and no second sync tool on the iPhone.
2. **Mac + Android (± second computer):**
   - Sync: Syncthing on all desktops plus Syncthing-Fork on Android. Use staggered versioning (maxAge 90–365 days) on *every* device so each one archives the others' changes.
   - Ignore `.git` and `workspace*.json`.
   - Git on one "primary" Mac, plus Time Machine.
   - Alternatively, on Android use git only, through GitSync. Never use GitSync and Syncthing on the same folder.
3. **Mac + iPhone + Android/Windows:** pick one:
   - **(a) LiveSync** (R2 free tier or CouchDB, E2EE) on all devices, with git and Time Machine on the Mac as independent history. Pin the LiveSync version. Highest capability, highest complexity.
   - **(b) Syncthing** on desktop/Android, with Möbius ($4.99) or SyncTrain on iOS. Accept foreground-only iOS sync.
   - **(c) Git everywhere:** the plugin on desktop, GitSync on mobile. Highest auditability, most manual conflict handling.
- **Golden rules** beyond "sync ≠ backup":
  - One sync engine per vault folder, and one git writer per repo at a time.
  - Keep `.git` and agent worktrees out of synced folders.
  - Version on the machine where most edits (and all agent edits) happen.
  - Every layer must cover local edits, which Syncthing versioning does not.
  - Keep at least one history copy off-device: a git remote, or a Time Machine disk.
  - After any sync incident, diff before deleting conflict copies.

### Gaps
- No direct Reddit (r/ObsidianMD) threads were fetched this session, so community consensus relies on the Obsidian forum, HN summaries and 2026 blog guides.
- No quantitative data (e.g., incident rates) comparing iCloud, Syncthing and git exists in the sources found.
