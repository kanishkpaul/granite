# Spec: granite-mcp (read-only, phase 0/1)

Status: **built** (spike D, decision 0004). Plan refs: §4.1, §6.5, §6.6, §8 spike D, phase 1 scope ("`granite-mcp` read-only (search, get_note, backlinks)").

## Inputs
- `granite-mcp --vault <folder> [--db <index.sqlite>]`, launched by an MCP client over stdio.
- The vault's `index.sqlite` (opened **read-only**; built by the app or `granite-cli index`) and `.granite/policy.yaml`.

## Tools
| Tool | Arguments | Returns |
|---|---|---|
| `search` | `query`, `limit` (≤ 50, default 10), `folder?`, `include_ai?` (default false) | Best block per note: path, line, heading path, block id, origin, type, trust, snippet, and a ready-to-paste citation `[[Title#^block]]` or `path:line` |
| `get_note` | `path` or `id`, `start_line?`, `end_line?` | Note text (with frontmatter) plus a header: path, id, type, origin, trust |
| `get_backlinks` | `path` | Notes linking to it, with relation (`links`, `embed`, `supports`, `supersedes`, …) and line |
| `list_recent` | `limit` (≤ 100, default 20), `since?` (ISO date) | Recently modified notes, newest first |

All tools are annotated read-only. Phase 3 adds `propose_change` and `create_derived_note`.

## Visibility rules (enforced in code, plan §6.5)
- Only notes whose effective label is `cloud` are visible: the MCP client sends content to a cloud model.
- Folders with `mcp: hidden` (Private/ in the built-in policy) are invisible regardless of label.
- A hidden note answers exactly like a missing one ("no visible note"), so its existence does not leak.
- `get_note` serves only paths present in the index, so arbitrary files (`../`, `.git/`, absolute paths) are unreachable.
- Search excludes `AI/` unless `include_ai` (evidence scope, principle 4). Untrusted clippings are labelled `trust: untrusted` in every result.

## Audit
Every call appends one JSON line to `~/Library/Application Support/granite/<vault-id>/mcp-audit.jsonl`: time, tool, result count, and the paths returned. Never note content or the query text. Moves into `state.sqlite` when that exists.

## Failure handling
- No index or a schema mismatch: a clear error telling the user to run the app or `granite-cli index`; the server never rebuilds the index itself.
- Bad arguments: tool result with `isError: true` and the reason.

## Files
`Tools/granite-mcp/Sources/GraniteMCPKit/` (handlers, visibility, audit), `Tools/granite-mcp/Sources/granite-mcp/main.swift`, tests in `Tools/granite-mcp/Tests/`. KBIndex gains a read-only open mode, `note(path:)`, `note(id:)`, `recent(limit:since:)`.

## Done when
- [x] 10 tests over the in-memory MCP transport: tools listed, each tool works, hidden and non-cloud notes never appear, path escapes refused.
- [ ] Claude Code answers a question through the server, citing a fixture note path (blocked: CLI sign-in expired; command in decision 0004).
- [ ] Registered from the app bundle (`granite.app/Contents/MacOS/granite-mcp`) and launched by Claude Desktop.
