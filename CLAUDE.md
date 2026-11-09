# granite: rules for agents

granite is a personal, native macOS knowledge base. Read `docs/MASTER-PLAN.md` before any feature work; it holds the architecture, schemas, AI layer and roadmap. `docs/research/` holds the research behind it (`[R …]` tags in the plan point there).

Current phase: **1, daily driver** (`docs/specs/phase-1.md`; plan §8). Built: quick capture (`KBCapture`, `App/Capture/`), git auto-commit with the deletion alarm (`KBGit`), the app shell (`App/Shell/`: sidebar, list, inspector, ⌘O switcher, ⌘K palette, ⌘N, ⌘D), editor polish (bridge protocol v3: completion, embeds, external-change banner, inline related items), Inbox decide queue and rename/move with link rewriting. Phase 2: model router (`KBAI`, `state.sqlite`), hybrid search in the app and the bundled `granite-mcp` helper (`App/MCPHelper`, built by XcodeGen with MLX), grounded Q&A, proposal queue with see-also link proposals (`KBIndex.ProposalStore`, `RelatedFinder`), inline related items (`App/Related.swift`, `Editor/src/related.ts`), native papers (`KBPapers`, `App/Papers/`, decision 0008), opt-in MLX language model. Phase 3: claim ledger (`KBIndex.ClaimService`, `App/Claims/`), FSRS prompts (`KBReview`, `App/Review/`). Progress for phases 1–4: `docs/PROGRESS.md`. Phase 0: Built: `KBCore`, `KBIndex` (FTS, chunks, vectors, hybrid search, watcher), `KBTestSupport`, `KBAI` (route probe only), `KBAIMLX` (EmbeddingGemma, Qwen3 reranker), `Tools/granite-ml`, `Tools/granite-cli`, `Tools/granite-mcp` (read-only), `Editor/` (CM6) and a thin `App/` shell with search and editing. Spike B part 1 passed (`docs/decisions/0001`); spike A passed its automated gates (`0003`, manual IME checks pending); spike D built (`0004`, Claude Code smoke test pending); spike C (Zotero) deferred (`0005`); file watcher built (`0006`); spike B part 2 (MLX hybrid search) built (`0007`).

To check UI layout, run the built app with `--snapshot out.png --open <note path>` (outside the command sandbox; it renders the window to PNG and quits). The window capture misses plain SwiftUI content in the list column (only `List` rows draw); `--select proposals` also writes `out.proposals.png` with `ImageRenderer`, the pattern to copy for other views. To test `granite://` URLs, copy the built app into `build/` (git-ignored) and register it with `lsregister -f`: LaunchServices ignores apps inside temp folders.

Run `scripts/test-all.sh` (add `--app` to also run the app's tests) before calling work done. After changing `Editor/src`, run `pnpm build` there: the built bundle in `App/Resources/editor/` is committed.

## Code
- Swift 6, strict concurrency. `@Observable` + `@MainActor` models, actors for background work, async/await only. Never `ObservableObject`, Combine, `DispatchQueue` or `Timer.scheduledTimer`.
  - One exception: `KBIndex.FileWatcher` owns a private serial `DispatchQueue` solely as the FSEvents callback queue (the C API needs a queue or run loop), bridged straight into an `AsyncStream`. Nothing else uses Dispatch.
- Explicit numeric conversions (Int/Int32/Double/Float). No force unwraps outside tests.
- Logic goes in `Packages/*`; `App/` stays thin. Every package change ships with `swift test` passing.
- Only `KBAI`, `KBAIMLX`, `Tools/granite-ml` and `App` may import FoundationModels or MLX. `KBCore`, `KBIndex`, `KBPapers`, `KBReview` and `KBZotero` stay macOS-26-clean. `KBIndex` defines the `Embedder`/`Reranker` protocols; MLX implementations live in `KBAIMLX`.
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
