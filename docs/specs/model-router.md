# Spec: model router, audit and budget (KBAI + state.sqlite)

Status: **built** (phase 2). Plan refs: §6.1 routing, §6.6 audit, §6.7 budget, §4.6 `state.sqlite`, principle 7.

## Inputs
- A task (`tagging`, `linkReason`, `contextPrefix`, `triage`, `qa`, `qaDeep`, `socratic`, `extraction`, `nli`, `digest`, `synthesis`, `beliefDiff`), the AI labels of every note whose text goes in, the note paths, and the request (system, prompt, citable documents or an output schema).
- Whether a person is waiting (`interactive`) or it's a background job.

## Routing (pure, `Router`)
- The strictest label wins. `none` refuses everything; `local` allows on-device and MLX; `pcc` adds Apple PCC; only `cloud` allows Claude.
- Per task, routes in preference order (§6.1): small tasks on device; Q&A Haiku 5.5 → PCC → on-device/MLX; deep Q&A and Socratic review Sonnet 5.5; extraction, NLI and digests Sonnet 5.5 or local; literature synthesis Opus 5.5 or Sonnet 5.5 only (never local); belief diff Opus 5.5 or local.
- Budget: at the alert level a notice is shown; at the hard stop, background jobs lose the Claude routes (interactive questions still run).
- Unavailable routes are skipped with a notice naming the fallback.

## Providers
| Route | Provider | Notes |
|---|---|---|
| on-device, pcc | `AppleProvider` (FoundationModels) | Structured output by guided generation over a dynamic schema; documents inlined, untrusted ones fenced as data |
| haiku, sonnet, opus | `ClaudeProvider` (Messages API over HTTPS, API version `2026-10-21`) | Grounded answers send passages as `document` blocks with citations; structured output via `output_config.format` (not combined with citations); Sonnet and Opus use server-side refusal fallback (`fallbacks: "default"`); refusals and max-token stops are checked before reading content; 429/5xx retried twice, honouring `retry-after`; system prompt cached |
| mlx | `KBAIMLX.MLXLanguageProvider`: opt-in (Settings → AI), Qwen3 4B, Gemma 4 E4B or Qwen3 8B (default) 4-bit via `mlx-swift-lm`; available only when on **and** downloaded, so a request never starts a download; JSON by prompt hint + extraction (no guided generation); Qwen3 runs with `/no_think` and any `<think>` block is stripped | `granite-ml generate --model mlx-community/Qwen3-0.6B-4bit --json …`: JSON decoded, 2.5 s after a one-time load |

The API key lives in the login Keychain (Settings → AI); `ANTHROPIC_API_KEY` in the environment overrides it for development.

## ModelService
- Decides, tries routes in order, falls back on failure (not on refusals), and cools a failed route down for an hour (PCC can report available and still fail; decision 0004).
- Audits every attempt in `state.sqlite`: time, route, model, task, effective label, tokens, dollars, note paths (never content), prompt hash, outcome.
- Returns the effective label so anything written from the result inherits it (taint).

## state.sqlite
`audit`, `feature_events` (shown/accepted/edited/rejected per feature, for acceptance rates and auto-pause), `search_events`, `qa_log` (abstentions, verification counts, your verdicts), `metrics` (weekly). Migrations, never rebuilt.

## Done when
- [x] Tests: routing table, label limits, taint, `none`, budget alert and hard stop, synthesis cloud-only, pricing, schema translation, JSON extraction, fallback order and audit rows, refusal stops fallback, cool-down, Claude request shape (headers, documents, citations, effort, fallbacks, structured output), refusal/truncation/retry/auth errors, real on-device structured output.
- [x] Settings → AI: key entry, available routes, monthly spend vs budget, what left this Mac this week.
- [x] MLX route smoke test (`granite-ml generate`, small Qwen3).
- [ ] With your Claude key: one real Haiku call from the app (you).
- [ ] Optional: turn on the local model in Settings and download it (2.3–4.6 GB) if private notes need more than the on-device model.
