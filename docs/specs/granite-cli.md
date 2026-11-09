# Spec: granite-cli

Status: **built** (phase 0). Plan refs: §4.1, §9 ("the agents' main lever").

## Commands
| Command | Does |
|---|---|
| `fixture --notes N --out DIR [--seed S] [--queries Q]` | Writes a deterministic synthetic vault plus `.granite/eval/synthetic.jsonl`. Refuses non-empty folders. |
| `index --vault V [--db PATH] [--rebuild]` | Reconciles the index; prints the report. |
| `search --vault V QUERY… [--limit] [--include-ai] [--max-label L] [--folder F] [--raw] [--json]` | BM25 search, best block per note. |
| `titles --vault V TEXT` | Quick-switcher match on titles and aliases. |
| `backlinks --vault V PATH` | Incoming links with relation and line. |
| `stats --vault V` | Counts and the most-used unresolved links. |
| `eval --vault V [--queries JSONL] [--repeats N]` | Recall@5/10, MRR, latency p50/p95. |
| `parse FILE [--path P]` | How granite parses one file: properties, tags, links, blocks. |

`--db` defaults to `~/Library/Application Support/granite/<vault-id>/index.sqlite`.

## Usage
```bash
cd Tools/granite-cli && swift build -c release
.build/release/granite-cli fixture --notes 50000 --out /tmp/g50k
.build/release/granite-cli index --vault /tmp/g50k --db /tmp/g50k-index/index.sqlite
.build/release/granite-cli eval --vault /tmp/g50k --db /tmp/g50k-index/index.sqlite
```

## Done when
- [x] All commands run against the 50k fixture.
- [ ] `lint` (orphans, unresolved links, missing properties) when phase 3's lint lands.
