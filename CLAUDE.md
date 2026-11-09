# granite: rules for agents

granite is a personal, native macOS knowledge base. Read `docs/MASTER-PLAN.md` before any feature work; it holds the architecture, schemas, AI layer and roadmap. `docs/research/` holds the research behind it (`[R …]` tags in the plan point there).

Status: phases 1–4 are built and tested; their gates measure your use and are open (`docs/PROGRESS.md`, plan §8). Where things live:
- Core: `KBCore` (parsing, policy, `SafeWriter`, proposals, claims, trails, weekly notes), `KBIndex` (FTS, chunks, vectors, hybrid search, watcher, proposal store, related notes, claims, lint, metrics), `KBTestSupport`.
- Capture and vault: `KBCapture` (capture, Inbox queue, `granite://` URLs, clippings), `KBGit` (auto-commit, deletion alarm, commits and trailers), `KBPapers` (PDF import, OCR, highlights, enrichment, Docling, literature graph), `KBReview` (FSRS prompts), `KBCode` (repos, ADRs, decision records).
- AI: `KBAI` (router, Claude and Apple providers, grounded Q&A, digest, prompt drafter, NLI, contradictions, belief diff, wiki), `KBAIMLX` (EmbeddingGemma, Qwen3 reranker, opt-in MLX language model).
- Tools: `Tools/granite-cli`, `Tools/granite-ml` (MLX, xcodebuild only), `Tools/granite-mcp` (read tools plus `propose_change`, `create_derived_note`; `--read-only`).
- Editor: `Editor/` (CM6, bridge protocol v3 with inline related items; `clipper.ts` with Defuddle).
- App: `App/Shell` (window, palette, Proposals), `App/Papers`, `App/Claims`, `App/Review` (prompts, weekly review, metrics), `App/Trails` (trails, wiki), `App/Code`, `App/Clipper`, `App/Intents`, `App/Nightly.swift` (3 a.m. digest), `App/MCPHelper` (bundled MCP server).
- Decisions `docs/decisions/0001`–`0008`; specs in `docs/specs/`. Pending by hand: spike A IME checks (`0003`), Claude Code MCP smoke test (`0004`).

To check UI layout, run the built app with `--snapshot out.png --open <note path>` (outside the command sandbox; it renders the window to PNG and quits). The window capture misses plain SwiftUI content in the list column and sheets (only `List` rows and the editor draw); `--select proposals` also writes `out.proposals.png` with `ImageRenderer`, the pattern to copy for other views. Snapshot flags also drive features end to end (`--suggest`, `--digest`, `--metrics`, `--weekly`, `--import-pdf`, `--pdf`, `--enrich`, `--graph`, `--clip`, `--wiki`, `--scan-repo`, …; see `App/Shell/Snapshot.swift`) and log results with `NSLog`. Point the app at a scratch vault with `defaults write local.granite.app granite.vaultPath <folder>` and delete the key afterwards; then run `--clear-spotlight` with no vault set, so scratch notes don't stay in Spotlight. To test `granite://` URLs, copy the built app into `build/` (git-ignored) and register it with `lsregister -f`: LaunchServices ignores apps inside temp folders.

Run `scripts/test-all.sh` (add `--app` to also run the app's tests) before calling work done. After changing `Editor/src`, run `pnpm build` there: the built bundles in `App/Resources/editor/` (`editor.js`, `clipper.js`) are committed.

## Code
- Swift 6, strict concurrency. `@Observable` + `@MainActor` models, actors for background work, async/await only. Never `ObservableObject`, Combine, `DispatchQueue` or `Timer.scheduledTimer`.
  - One exception: `KBIndex.FileWatcher` owns a private serial `DispatchQueue` solely as the FSEvents callback queue (the C API needs a queue or run loop), bridged straight into an `AsyncStream`. Nothing else uses Dispatch.
- Explicit numeric conversions (Int/Int32/Double/Float). No force unwraps outside tests.
- Logic goes in `Packages/*`; `App/` stays thin. Every package change ships with `swift test` passing.
- Only `KBAI`, `KBAIMLX`, `Tools/granite-ml` and `App` may import FoundationModels or MLX. `KBCore`, `KBIndex`, `KBCapture`, `KBGit`, `KBPapers`, `KBReview`, `KBCode` and `KBZotero` stay macOS-26-clean (`KBAI` and `KBAIMLX` need macOS 27). `KBIndex` defines the `Embedder`/`Reranker` protocols; MLX implementations live in `KBAIMLX`.
- Anything that runs MLX builds with `xcodebuild`, not `swift build` (SwiftPM cannot compile MLX's Metal shaders). `scripts/test-all.sh --ml` does this.
- Never edit `project.pbxproj`. Edit `project.yml` and run `xcodegen`.
- `Editor/` uses pnpm, Vite and Vitest. The bridge protocol lives in `Editor/src/bridge.ts` and `App/Bridges/EditorBridge.swift`; change both together, with a round-trip test.

## Data
- Never touch the real vault (`~/Vault`). Use `Fixtures/` or `swift run granite-cli fixture --notes 50000 --out /tmp/...`.
- Markdown is truth; `index.sqlite` is disposable. Schema changes bump the version and rebuild.
- File writes go through `KBCore.SafeWriter` (NSFileCoordinator + echo suppression).
- AI code: no tool may write outside `AI/`; changes to other files are proposals.

## Process
- Before a feature, write or read its spec in `docs/specs/<feature>.md` (inputs, outputs, files touched, done-when). After, update it.
- One package per session where possible. Use git worktrees for parallel agents.
- Record every spike outcome as a decision record in `docs/decisions/`.
- Apple's newest APIs (FoundationModels, App Intents 27) postdate most training data: check `docs/apple/` or current Apple docs before using them.
- When I correct you, propose an edit to this file in your summary.
