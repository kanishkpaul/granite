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

## Write tools (phase 3)
- `propose_change(target, kind, diff, rationale, citations?)`: writes one file in `AI/Proposals/` (feature `mcp`) and nothing else; the user accepts, edits or rejects it in the app. Kinds: link, edit, tag, prompt, rule, claim. The target must be a visible note outside `AI/` (a claim names a new path in a visible folder). An edit whose `-` lines don't match the note is refused at once, with the reason. Same cap (25 open) and duplicate rules as the app (`KBIndex.ProposalFiles`, which reads the files, so it works while the app is closed; the app's watcher indexes them).
- `create_derived_note(path, body, sources)`: a new `.md` under `AI/` (not `AI/Proposals`, `AI/Digests`, `AI/Metrics` or `AI/log.md`), stamped `type: synthesis`, `origin: ai`, `ai: cloud`, with `sources` and `derived_from`. Never overwrites. Every source must be a note the client can see.
- `get_claims(topic?, status?, limit?)` (read): the claim ledger, visible claims only.
- `--read-only` (both builds) drops the two write tools; calls to them then fail.
- `SafeWriter` enforces the AI role in code: these tools can't write outside `AI/` even with a bug in the handler.

## Audit
Every call appends one JSON line to `~/Library/Application Support/granite/<vault-id>/mcp-audit.jsonl`: time, tool, result count, and the paths returned. Never note content or the query text. Moves into `state.sqlite` when that exists.

## Failure handling
- No index or a schema mismatch: a clear error telling the user to run the app or `granite-cli index`; the server never rebuilds the index itself.
- Bad arguments: tool result with `isError: true` and the reason.

## Files
`Tools/granite-mcp/Sources/GraniteMCPKit/` (handlers, visibility, audit), `Tools/granite-mcp/Sources/granite-mcp/main.swift`, tests in `Tools/granite-mcp/Tests/`. KBIndex gains a read-only open mode, `note(path:)`, `note(id:)`, `recent(limit:since:)`.

## Done when
- [x] 14 tests over the in-memory MCP transport: tools listed (and read-only mode), each tool works, hidden and non-cloud notes never appear, path escapes refused; proposals never change the note, duplicates and mismatched edits refused; derived notes only under AI/, never overwritten, sources must be visible.
- [ ] Claude Code answers a question through the server, citing a fixture note path (blocked: CLI sign-in expired; command in decision 0004).
- [x] Bundled in the app at `granite.app/Contents/MacOS/granite-mcp`, with hybrid search when the vault has vectors (`mode: hybrid|bm25`).
- [ ] Registered in Claude Code / Claude Desktop from the bundle (you): `claude mcp add granite -- /Applications/granite.app/Contents/MacOS/granite-mcp --vault ~/Vault`.
