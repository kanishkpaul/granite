# 0002: KBCore parsing, policy defaults and repo layout

Date: 2026-11-09 · Status: **accepted** · Plan: §3, §4.1, §4.3, §4.5

## Decisions

1. **Hand-written line and inline scanners, not swift-markdown, for indexing.** The index needs blocks, heading paths, links, tags, block IDs and callouts, all Obsidian-specific. A one-pass scanner over UTF-8 lines and Unicode scalars handles these directly and indexes 50k notes in 20 s. Swift `Regex` was avoided on the hot path for speed. swift-markdown stays available for rendering-grade parsing later (export, previews) if needed.

2. **Never re-serialize YAML.** Frontmatter edits insert or replace a single line, so untouched bytes stay identical (tested on every golden note). An edit into YAML that does not parse is refused rather than risk corrupting the file.

3. **Unknown folders fail closed.** The plan's policy lists Notes, Daily, Inbox, Papers, Clippings, Private and AI. The built-in policy adds References, Code and Projects as `cloud` (the plan's layout implies they are ordinary human/source material). Anything else (vault root, Archive, Attachments, new folders) defaults to `ai: local`, `agents: propose`. A `default:` entry in `policy.yaml` overrides this.

4. **A note's `ai:` can only tighten its folder label.** `AI/` files are always `origin: ai`, whatever their frontmatter says, so AI text cannot be laundered into evidence.

5. **Packages are created when their phase starts.** Day 1 of the plan lists every package; empty SwiftPM targets add noise and fail `swift test` without placeholder tests. Today: `KBCore`, `KBIndex`, `KBTestSupport`, `Tools/granite-cli`. The dependency rule in §4.1 still governs new ones.

6. **Decision records live in `docs/decisions/`** (per CLAUDE.md) rather than the vault's `Code/` folder the plan mentions, until the vault exists.

## Open
- **FSEvents vs. the no-`DispatchQueue` rule.** `FSEventStreamSetDispatchQueue` (or a run loop) is the only way to receive FSEvents callbacks. Proposed CLAUDE.md amendment: allow a private serial `DispatchQueue` solely as the callback queue for C APIs (FSEvents), bridged straight into an `AsyncStream`.
