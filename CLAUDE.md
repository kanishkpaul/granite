# granite: rules for agents

granite is a personal, native macOS knowledge base. Read `docs/MASTER-PLAN.md` before any feature work; it holds the architecture, schemas, AI layer and roadmap. `docs/research/` holds the research behind it (`[R …]` tags in the plan point there).

Current phase: **0, spikes** (see plan §8). Built: `KBCore`, `KBIndex` (FTS, chunks, vectors, hybrid search, watcher), `KBTestSupport`, `KBAI` (route probe only), `KBAIMLX` (EmbeddingGemma, Qwen3 reranker), `Tools/granite-ml`, `Tools/granite-cli`, `Tools/granite-mcp` (read-only), `Editor/` (CM6) and a thin `App/` shell with search and editing. Spike B part 1 passed (`docs/decisions/0001`); spike A passed its automated gates (`0003`, manual IME checks pending); spike D built (`0004`, Claude Code smoke test pending); spike C (Zotero) deferred (`0005`); file watcher built (`0006`); spike B part 2 (MLX hybrid search) built (`0007`).

Run `scripts/test-all.sh` (add `--app` to also run the app's tests) before calling work done. After changing `Editor/src`, run `pnpm build` there: the built bundle in `App/Resources/editor/` is committed.

## Code
- Swift 6, strict concurrency. `@Observable` + `@MainActor` models, actors for background work, async/await only. Never `ObservableObject`, Combine, `DispatchQueue` or `Timer.scheduledTimer`.
  - One exception: `KBIndex.FileWatcher` owns a private serial `DispatchQueue` solely as the FSEvents callback queue (the C API needs a queue or run loop), bridged straight into an `AsyncStream`. Nothing else uses Dispatch.
- Explicit numeric conversions (Int/Int32/Double/Float). No force unwraps outside tests.
- Logic goes in `Packages/*`; `App/` stays thin. Every package change ships with `swift test` passing.
- Only `KBAI`, `KBAIMLX`, `Tools/granite-ml` and `App` may import FoundationModels or MLX. `KBCore`, `KBIndex`, `KBReview` and `KBZotero` stay macOS-26-clean. `KBIndex` defines the `Embedder`/`Reranker` protocols; MLX implementations live in `KBAIMLX`.
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
