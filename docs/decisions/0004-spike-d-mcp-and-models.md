# 0004: Spike D, granite-mcp and the model-route matrix

Date: 2026-11-09 · Status: **accepted; Claude Code and Desktop smoke tests pending** · Plan: §6.1, §6.5, §8 spike D, §12 gaps 5, 7, 8

## What was built
- `Tools/granite-mcp`: stdio MCP server on `modelcontextprotocol/swift-sdk` **0.12.1** (newer than the plan's 0.11; protocol `2025-11-25`). Tools: `search`, `get_note`, `get_backlinks`, `list_recent`, all annotated read-only. Handlers live in the `GraniteMCPKit` library; the executable is 30 lines.
- `KBIndex`: a read-only open mode that never creates or rebuilds the index, plus `note(path:)`, `note(id:)`, `recent(limit:since:)`.
- `Packages/KBAI` (macOS 27): `ModelProbe`, the first piece of the router. `granite-cli models [--send]` prints the route matrix.

## MCP results
| Check | Result |
|---|---|
| Swift SDK builds under Swift 6 strict concurrency | yes |
| 10 end-to-end tests over the SDK's in-memory transport | pass |
| Raw stdio JSON-RPC against the release binary on the 50k index | initialize + search answer correctly |
| Only `cloud` notes visible; `Private/` and other `mcp: hidden` folders invisible; `local`/`pcc` notes invisible | enforced in `GraniteTools.isVisible`, tested for search, get_note, backlinks, recent |
| Hidden note indistinguishable from a missing one | tested (identical error text) |
| Path escapes (`../`, `/etc/hosts`, `.git/config`) | refused: `get_note` serves only indexed paths |
| Audit log holds tool + paths, never content or query text | tested |
| **Claude Code cites a note through the server** | **not run**: the terminal `claude` CLI's sign-in had expired |
| Claude Desktop launches the helper from the app bundle | not run (the helper is not bundled into the app yet) |

## Model routes on this Mac (M5, macOS 27.0.1)
| Route | Available | Context | One-line prompt |
|---|---|---|---|
| Apple on-device | yes | **8,192 tokens** | "ready" in 1,502 ms cold, 863 ms warm |
| Apple PCC | reports available, quota below limit | **32,768 tokens** | **fails**: `LanguageModelError -1` wrapping `ModelManagerError 1046` from an ad-hoc-signed binary |
| MLX | not wired (spike B part 2) | | |
| Claude | not wired (Messages client + Keychain key) | | |

## Decisions
1. **Keep the Swift MCP SDK.** It works with a clean API and an in-memory transport for tests, so no port to the TypeScript SDK is needed.
2. **Visibility is one function.** Every MCP result passes `isVisible(path:label:)`: label `cloud` and not `mcp: hidden`. Search additionally filters with `maxLabel: .cloud` in SQL.
3. **The MCP server never writes the index.** A missing or outdated index is an error that names the fix (`granite-cli index` or open the app). Phase 3's `propose_change` will write only to `AI/Proposals/` through `SafeWriter`'s `.ai` role.
4. **The audit log is JSONL for now** (`<support>/mcp-audit.jsonl`), until `state.sqlite` exists.
5. **On-device context is 8K here**, so on-device tasks (tags, titles, link reasons, contextual prefixes) can take a full note chunk plus instructions.
6. **Treat PCC as unavailable until a request succeeds.** `availability` said available while every request failed. The likely cause is PCC's managed entitlement, which an ad-hoc-signed binary lacks; this is unconfirmed. The router must fall back to MLX or Haiku on a PCC request failure, as the plan already allows. Recheck once the app is signed with a team ID (Developer Program, plan gap 9).
7. **`granite-cli` now targets macOS 27**, because it links `KBAI` for `models`. The core packages stay macOS 26.

## To finish the gate (you)
Sign the CLI back in (`claude`, then `/login`), then run this from the repo root. It uses a throwaway config, so nothing is registered permanently:

```bash
S=$(mktemp -d); V=$S/vault; mkdir -p $V/Notes
printf -- '---\ntype: claim\n---\nHybrid search plus a reranker matters more than the embedding model. ^c1\n' > "$V/Notes/Hybrid retrieval.md"
(cd Tools/granite-cli && swift run -c release granite-cli index --vault $V --db $S/index.sqlite)
(cd Tools/granite-mcp && swift build -c release)
printf '{"mcpServers":{"granite":{"command":"%s","args":["--vault","%s","--db","%s"]}}}' "$PWD/Tools/granite-mcp/.build/release/granite-mcp" "$V" "$S/index.sqlite" > $S/mcp.json
claude -p "Using only the granite tools, what does my vault say about hybrid retrieval? Cite the note." --mcp-config $S/mcp.json --strict-mcp-config --allowedTools mcp__granite__search mcp__granite__get_note < /dev/null
```

Pass: the answer cites `Notes/Hybrid retrieval.md` (or `[[Hybrid retrieval#^c1]]`).
