# Language and Technology Stack Decision for a Local-First Mac Knowledge-Base App (as of November 2026)

Scope: the comparative language/stack choice only. Swift subsystem detail (TextKit 2, GRDB, PDFKit, App Intents) and the AI layer are covered by other researchers. This session ran 15 search/fetch calls. Claims marked "background, not re-verified" come from prior knowledge, not from a source fetched this session, so the report writer should treat them as lower confidence.

Candidates compared: (A) pure Swift/SwiftUI+AppKit; (A′) Swift app with one contained TypeScript component, a CodeMirror 6 editor in WKWebView; (B) Rust core + SwiftUI shell via UniFFI/swift-bridge; (C) Tauri 2 (Rust + TS UI); (D) Electron + TS; (E) Swift + Python (or TS/Bun) sidecar; (F) GPUI (Rust-native UI); (G) KMP/Compose, Flutter, Zig (brief).

---

## 1. Editor quality: rich Markdown live preview and large documents

### Takeaway
The editor is the one subsystem where the web stack has a real lead. CodeMirror 6 is mature and well understood by LLMs, and Obsidian's own editor runs on it. TextKit 2 has documented large-document scrolling problems and open bugs that third-party editors have to work around. A Swift app can still use CodeMirror 6 by hosting it in a WKWebView, so the editor choice does not force the whole stack.

### Cited Findings
- One Apple Developer Forums report says scrolling a ~1M-character `UITextView` was choppy under TextKit 2 and smooth after forcing TextKit 1 by touching `layoutManager`. A macOS commenter in the same thread reports that scrolling "degrades significantly above ~3000 lines". These are anecdotes, not benchmarks. — [Apple Developer Forums thread 729491](https://developer.apple.com/forums/thread/729491)
- STTextView is a TextKit 2-based replacement for NSTextView, built mainly as a source-code editor. Its README lists TextKit 2 bugs it works around, such as an `NSTextList` regression since macOS 14. — [STTextView (GitHub)](https://www.github.com/krzyzanowskim/STTextView)
- A third-party TextKit guide says full-document `ensureLayout` defeats TextKit 2's viewport layout, and that TextKit 2 estimates document height, which can make the scroll bar unstable. The source is unverified and secondary. — [TextKit Diagnostics guide](https://sitapix.github.io/apple-text/skills/apple-text-textkit-diag/)
- MDEditor is an open-source Markdown editor built on TextKit 2 and STTextView. No large-file benchmark was found for it. — [MDEditor (GitHub)](https://github.com/Seeingu/MDEditor)
- Raycast 2.0 found that rendering rich text in AI Chat was "noticeably faster" in its WebView frontend than in its v1 AppKit implementation. — [Raycast: A Technical Deep Dive Into the New Raycast](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)
- Tauri depends on Swift bridging to reach native APIs on macOS. The usual path is swift-rs with `@_cdecl` global functions called from `unsafe` Rust. tauri-swift-runtime (v0.1.2) offers a plugin-style bridge. — [swift-rs](https://github.com/amodm/swift-rs); [tauri-swift-runtime](https://docs.rs/crate/tauri-swift-runtime/latest/source/README.md)

### Inferences
- Background, not re-verified: Obsidian's editor is CodeMirror 6, and its "Live Preview" mode is built from CM6 decorations. Several native Mac Markdown editors (for example MarkEdit) embed CodeMirror 6 in a WKWebView inside a Swift app.
- Most notes are a few hundred lines, so TextKit 2's problem zone (thousands of lines, or ~1M characters) is the exception. Long notes, imported transcripts and clipped articles do reach it, though, and a "fast editor" requirement means the tail case matters.
- Building Obsidian-compatible live preview natively means writing a lot of custom attribute and attachment logic on TextKit 2: hiding syntax, wikilink widgets, embeds, callouts, tables. In CM6 this work is mostly decoration and widget code, with abundant prior art for LLMs to learn from.
- The editor can be its own component. A WKWebView editor keeps the rest of the app native (PDFKit, App Intents, Spotlight, Foundation Models). This is option A′, and it is a narrower version of what Raycast did.

### Gaps
- No rigorous benchmark compares TextKit 2, STTextView and CodeMirror 6 on 10k+ line Markdown documents. A one-day spike measuring typing latency and scroll FPS on a 50k-line file would settle it.
- WKWebView-in-SwiftUI integration costs (IME, accessibility, undo bridging, drag-and-drop) were not researched this session.

---

## 2. Access to Apple frameworks and PDF handling

### Takeaway
Apple's on-device stack (Foundation Models, Core ML, Core Spotlight, App Intents, Share and Safari extensions, PDFKit) is first-class only from Swift. Apple ships an official Python SDK for Foundation Models, but it is a beta aimed at evaluation and batch work. Rust, Tauri and Electron reach these frameworks only through hand-written Swift or C shims. This is the strongest argument for a Swift host.

### Cited Findings
- Apple publishes an official Python SDK for Foundation Models (`apple-fm-sdk`, v0.2.0, beta), described as a Pythonic interface for evaluation and batch inference of Swift Foundation Models features. It requires macOS 26 or later with Apple Intelligence enabled. — [PyPI: apple-fm-sdk](https://pypi.org/project/apple-fm-sdk/)
- The unofficial `apple-foundation-models` Python package works through a Swift layer exposed via a C FFI and Cython, and it needs Xcode command-line tools to build its Swift dylib. In other words, non-Swift access is a Swift shim. — [PyPI: apple-foundation-models](https://pypi.org/project/apple-foundation-models/)
- Tauri's documented route to native Apple APIs on macOS is swift-rs (`@_cdecl` Swift functions, `unsafe` calls from Rust). No source documents Foundation Models use from Tauri or objc2. — [swift-rs](https://github.com/amodm/swift-rs); [tauri-swift-runtime](https://docs.rs/crate/tauri-swift-runtime/latest/source/README.md)
- Even after moving its UI to web technologies, Raycast kept a Swift/AppKit host for windows, global hotkeys, the menu bar, translucency, native tooltips and popovers, and supervising its backend. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)

### Inferences
- Background, not re-verified: App Intents, Core Spotlight indexing, Share extensions and Safari Web Extension containers are Swift and Xcode target types. Electron and Tauri apps can ship them only by adding Xcode-built appex targets, which means maintaining a Swift codebase anyway. MLX has first-party Swift (mlx-swift) and Python front-ends. PDFKit gives native PDF rendering, selection and annotation (another researcher is covering the details). Web stacks would use pdf.js, which is capable, but annotation persistence and macOS integration (Preview-compatible annotations, Quick Look) are weaker.
- Safari web clipping requires a Safari Web Extension, whose content scripts are JavaScript in every stack. Some TypeScript is therefore unavoidable for the clipper, which weakens the "Swift-only" ideal regardless of the main choice.
- For this app, the stacks that put Swift at the host level (A, A′, B, E) score highest on platform integration.

### Gaps
- I did not verify whether Apple added Foundation Models bindings for languages other than Swift and Python in 2026.

---

## 3. Performance, memory and startup

### Takeaway
Native Swift has the lowest memory floor, Tauri sits in the middle, and Electron is the heaviest. Raycast's own measurements show what a WebView+Node hybrid costs: roughly 150 MB more than its native v1. For a single-user app on Apple Silicon, all options are fast enough, so memory and startup should be secondary criteria.

### Cited Findings
- Raycast v1 (Swift/AppKit) typically used about 200–300 MB. Raycast v2 (Swift shell + WKWebView + Node backend + Rust indexer) uses about 350–450 MB. Breakdown: WebContent ~120–200 MB, Node ~150–200 MB, Swift shell ~40 MB, WebKit GPU ~18 MB, networking ~12 MB. An empty WebView is about 50 MB and a bare Node process about 12 MB. Raycast measures `phys_footprint` and warns that Activity Monitor double-counts shared frameworks. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)
- In one developer's macOS benchmark with six windows open, Tauri used ~172 MB and Electron ~409 MB, which they attribute to Chromium renderers using about twice the memory of WKWebView. Bundle sizes were 8.6 MiB for Tauri and 244 MiB for Electron, and the startup difference was "negligible". — [Hopp: Tauri vs Electron](https://dev.to/gethopp/tauri-vs-electron-performance-bundle-size-and-the-real-trade-offs-1el4)
- Better Stack reports Tauri at a 57 MB bundle, 311 ms startup and 109 MB memory, summing the main process and all webview processes. — [Better Stack comparison](https://betterstack.com/community/guides/scaling-nodejs/tauri-vs-electron-vs-deno-vs-electrobun/)
- A Tauri GitHub issue argues that WebKit's low baseline grows quickly under real web-app load (vscode.dev) and questions Tauri's benchmark tooling. — [tauri-apps/tauri#5889](https://github.com/tauri-apps/tauri/issues/5889)
- Raycast v2 tears down inactive windows to save memory, which causes short delays on cold opens. Raycast is adding grace periods to keep windows warm. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)

### Inferences
- At 10k–100k notes, the performance risk is in indexing and query design (incremental FS-event indexing, FTS5 or Tantivy, ANN vector search), not the UI language. Swift, Rust and Node can all do this, though Node is the weakest for CPU-bound parsing and embedding batch work.
- One WKWebView for the editor (option A′) costs roughly the "empty WebView ~50 MB" floor plus document content. That is far cheaper than Raycast's full Node backend.

### Gaps
- No source measured a pure SwiftUI notes app against Tauri and Electron with the same workload. Treat all cross-stack numbers as rough.

---

## 4. Ecosystem: search, vector, Markdown parsing, and MCP SDK availability

### Takeaway
On MCP SDK maturity, Rust, TypeScript and Python are Tier 1, while the official Swift and Kotlin SDKs are Tier 3 ("experimental/partial"). That is the clearest technical weak spot for an all-Swift build. Rust has the best search library (Tantivy). SQLite FTS5 and sqlite-vec are C libraries reachable from any language, which narrows Rust's advantage.

### Cited Findings
- On the official MCP SDK list, TypeScript, Python, C#, Go, Rust and Ruby are Tier 1. Java is Tier 2. Swift (`modelcontextprotocol/swift-sdk`), PHP and Kotlin are Tier 3. — [MCP SDKs page](https://modelcontextprotocol.io/docs/sdk)
- Tier criteria: Tier 1 needs 100% conformance-test pass, new protocol features before each spec release, triage within 2 business days, and critical fixes within 7 days. Tier 3 has no minimum conformance and no timeline commitment. Tiering was published on February 23, 2026, and SDKs are relegated after 4 weeks of failing tests. — [MCP SDK Tiering System](https://modelcontextprotocol.io/community/sdk-tiers)
- Raycast 2.0 uses Rust for a separate file-indexer process that scans the filesystem, builds a search index and updates it from FS events. Its data layer is shareable with iOS. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)
- AFFiNE's data engine, OctoBase, is a "light-weight, scalable" local-first engine written in Rust. The source is a GitHub mirror of the repo. — [OctoBase (GitHub mirror)](https://github.com/fourdim/OctoBase)

### Inferences
- An MCP server for this app mostly needs tools and resources over stdio (search, get note, list backlinks, create note). Background, not re-verified: this core subset is the most mature part of every SDK. Tier 3 Swift is therefore a manageable risk. The fallback is cheap: because the SQLite index is the contract, a separate `kb-mcp` server can be rewritten in TypeScript (Tier 1) against the same database without touching the app.
- At 100k notes, SQLite FTS5 (BM25, prefix and trigram tokenizers) is very likely sufficient. Tantivy's benefits (faster indexing, richer scoring, faceting) do not justify a Rust toolchain on day one. This is judgment; no benchmark was fetched.
- Markdown parsing, background not re-verified: Swift has apple/swift-markdown (cmark-gfm based) and SwiftPM ports of tree-sitter Markdown. TS has the richest Obsidian-flavor ecosystem (remark/micromark, unified, CM6 lezer-markdown). Rust has comrak and pulldown-cmark. Obsidian-specific syntax (wikilinks, embeds, callouts, block refs) needs custom extensions in every stack.

### Gaps
- Feature coverage of the Swift MCP SDK (which spec revision, OAuth, Streamable HTTP, elicitation) was not checked this session.
- No Swift-vs-Rust benchmark for FTS5 and sqlite-vec at 100k documents was found.

---

## 5. Agent build/test loop and how well LLMs write each language

### Takeaway
Evidence favors TypeScript for one-shot agent success. Frontier Claude models now write good Swift, but they lean on outdated idioms and stumble on Swift 6 concurrency and strict numeric types. Rust gets a strong compiler feedback loop but agents can thrash. The Xcode loop has improved a lot (Xcode 26.3 agentic MCP, XcodeBuildMCP). The biggest lever is structural: keep most logic in SwiftPM packages that `swift test` can build and test from the CLI without Xcode.

### Cited Findings
- Matt Gallagher (Dec 29, 2025) ran one-shot tests building a macOS SwiftUI/AVFoundation app. Claude Sonnet 4.5 scored 9/10 (only a missing `import Combine`, but it still used `ObservableObject` and `Timer.scheduledTimer`). Gemini 3 scored 8, GPT-5.2 scored 7, and local models scored 1–6. Common failures were outdated idioms, missing Swift 6 knowledge, Float/Double and Int32/Int conversions (he attributes these to training on "less-type-safe languages"), and unpredictability. He had earlier found agentic demos convincing mainly for JS and Python. — [Cocoa with Love: LLMs twelve months later](https://cocoawithlove.com/blog/llms-twelve-months-later.html)
- A December 2025 roundup reports that Claude Code's Swift output improves "significantly" with downloaded docs and spec-driven development, but "the chance of one-shotting tasks is still lower than with Typescript". — [Michael Tsai blog, Dec 31 2025](https://mjtsai.com/blog/2025/12/31/)
- John Gruber (June 2025) notes that there is no great corpus of Swift 6 code for LLMs to train on. — [Daring Fireball](https://daringfireball.net/linked/2025/06/07/swift-6-llms)
- MacPaw's SwiftEval (ICSE '25 FORGE) found multilingual benchmarks insufficient for Swift, and LLM scores dropped on problems that need Swift-specific features. — [SwiftEval (MacPaw Research)](https://research.macpaw.com/publications/swift_eval); [arXiv 2505.24324](https://arxiv.org/abs/2505.24324v1)
- Rust: an ICML 2026 paper says LLMs "still struggle with strongly typed languages such as Rust" and proposes on-the-fly compiler feedback. Practitioners praise Rust's diagnostics as a tight verification loop, but also report a "lint spiral" and agents adding redundant clones to satisfy the borrow checker. — [ICML 2026: LLM-Based Rust Code Generation with On-the-Fly Compiler Feedback](https://icml.cc/virtual/2026/82791); [DEV: Rust and LLMs](https://dev.to/arezvov/rust-and-llms-the-compiler-does-what-code-review-shouldnt-have-to-3ia4); [100k lines of AI-generated Rust](https://aiindigo.com/blog/ai-coding-agents-lessons-from-100k-lines-of-ai-generated-rust)
- Xcode 26.3 (February 2026) integrates Claude Agent and Codex and exposes Xcode capabilities over MCP. Agents can search docs, change project settings and capture Xcode Previews to check their work. It requires macOS 26. — [InfoQ](https://infoq.com/news/2026/02/xcode-26-3-agentic-coding); [SD Times](https://sdtimes.com/ai/xcode-26-3-adds-agentic-coding-support/)
- XcodeBuildMCP (now under getsentry) provides both a CLI and an MCP server for build, test and simulator control from Claude Code (`claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`). Telemetry is on by default. One HN commenter reports Xcode 26.3's own MCP output deviating from its schema, which is anecdotal. — [mcp.directory guide](https://mcp.directory/blog/xcodebuildmcp-complete-guide-2026); [XcodeBuildMCP repo](https://github.com/czottmann/XcodeBuildMCP)
- Raycast cited Swift compile times "creeping up" and the need to recompile and restart for UI changes in v1. Its v2 web UI hot-reloads in under a second. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)

### Inferences
- Rough per-stack loop speed, which is judgment: Vite/pnpm with HMR is fastest (<1 s). `cargo check` and `cargo test` are fast and CLI-native. `swift build` and `swift test` on a pure SwiftPM library are fine. The full `xcodebuild` app loop is slowest and most fragile for agents (signing, schemes, derived data).
- Mitigation for a Swift-first build: put indexing, parsing, search, the vault model and the MCP server in a `KBCore` SwiftPM package with `swift test` coverage, and keep the Xcode app target thin. Use `.claude` instructions that pin modern idioms (`@Observable`, not `ObservableObject`; Swift 6 strict concurrency; `async/await`) and keep current Apple docs in context. This directly targets the failure modes Gallagher and Tsai describe.
- A Rust core adds a second toolchain and an FFI boundary (UniFFI-generated bindings, XCFramework packaging) that agents must keep in sync. That increases loop complexity even though cargo itself is fast.

### Gaps
- No rigorous 2026 head-to-head benchmark of Claude Code on Swift vs TypeScript vs Rust was found. All evidence is anecdotal or from small benchmarks.

---

## 6. Real-world precedents and lessons from stack switches

### Takeaway
Successful notes apps use every stack. The pattern that matters is that teams with a cross-platform mandate move to web UI plus a native or Rust/Go core, while Apple-only apps stay native. This app is Apple-only and has one user, so the cross-platform pressure that drove Raycast and Anytype does not apply.

### Cited Findings
- **Raycast (2026):** moved from pure Swift/AppKit to Swift host + WKWebView React/TS UI + Node backend + Rust indexer. Reasons: Windows support, AppKit "getting in our way more often", compile times, and the difficulty of hiring AppKit talent. It evaluated Electron (less suitable), Tauri ("too young" for them at the time) and a custom hybrid, and picked the hybrid. SwiftUI "never quite cleared our bar for performance and control". Cost: memory rose from 200–300 MB to 350–450 MB. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)
- **Anytype:** desktop is Electron + React + MobX talking to a Go middleware (anytype-heart) that handles sync, storage and crypto. A separate native Swift repo (anytype-swift) exists for iOS. — [DeepWiki: anytype-ts](https://deepwiki.com/anyproto/anytype-ts); [anytype-swift](https://www.Github.com/anyproto/anytype-swift)
- **AFFiNE:** Rust data engine (OctoBase) plus the BlockSuite editor. The source is a mirror README. — [OctoBase](https://github.com/fourdim/OctoBase)
- **Logseq:** split into "Logseq OG" (file-based Markdown, maintained with no new features) and a DB version that inherits the roadmap. A review calls the DB version an early beta that can lose data. — [Kompozy review of Logseq 2.0](https://kompozy.io/reviews/logseq-2-0)
- **Element X iOS:** a SwiftUI client on matrix-rust-sdk through an FFI layer packaged as a Swift package, shared with Element X Android. This is the canonical production example of option B. — [element-x-ios](https://github.com/element-hq/element-x-ios)
- **Longbridge Pro:** a commercial trading desktop app built on GPUI via gpui-component. See section 7. — [gpui-component](https://github.com/longbridge/gpui-component)

### Inferences
- Background, not re-verified: Obsidian is Electron + CodeMirror 6 + pdf.js. Bear, Craft, NotePlan and DEVONthink are native (Swift/ObjC). Zed is Rust/GPUI. Logseq OG is ClojureScript on Electron. These match the pattern above: native for Apple-only polish, web for cross-platform reach.
- Lesson from Logseq: changing the source-of-truth storage model is costlier than changing the UI language. The decision to keep plain Markdown as the truth and SQLite as a rebuildable index matters more than the language choice and should not be compromised.
- Lesson from Raycast: even a team that left native kept Swift for OS integration and used Rust only for the hot indexing path. Language boundaries that sit on process boundaries (separate indexer process, separate MCP binary) are the maintainable ones.

### Gaps
- No primary engineering posts were fetched for Obsidian, Bear, Craft or DEVONthink this session.
- No published lessons on UniFFI pitfalls from the Element X team were found.

---

## 7. Is GPUI (or another Rust-native UI) viable for this in 2026?

### Takeaway
Not for this app. GPUI is pre-1.0, has frequent breaking changes and thin docs, and gives no access to PDFKit, App Intents or Foundation Models. One commercial app (Longbridge Pro) shows it can ship, but the PDF, extension and on-device-ML requirements rule it out.

### Cited Findings
- GPUI is "still in active development" alongside Zed, is pre-1.0 with "often" breaking changes, and its docs point developers to the Zed source and Discord to learn the APIs. Community forks (bezel-gpui, xgpui, gpui-pre) publish it on crates.io with independent release cycles. — [bezel-gpui README](https://docs.rs/crate/bezel-gpui/latest/source/README.md); [xgpui docs](https://docs.rs/xgpui/=2.0.0/)
- gpui-component was extracted from Longbridge Pro and is "production ready" per its README. It is at version 0.4–0.5, its install pulls GPUI from Zed's git repository rather than a published crate, and its WebView element is "early and experimental". — [gpui-component](https://github.com/longbridge/gpui-component); [docs.rs gpui-component 0.4.0](https://docs.rs/crate/gpui-component/0.4.0/source/README.md)

### Inferences
- GPUI has no PDF renderer or annotation layer, no rich-text Markdown editor component aimed at prose (Zed's editor is code-oriented), and no Apple-extension story. LLMs also have little GPUI training data. It scores lowest in the matrix.

### Gaps
- Other Rust UI toolkits (Slint, Dioxus native, Iced, Xilem/Masonry) were not researched this session.

---

## 8. Others: Kotlin Multiplatform/Compose, Flutter, Zig

### Takeaway
None is credible for this app. The official Kotlin MCP SDK is Tier 3 (same as Swift), Compose and Flutter on macOS add a non-native rendering layer without solving Apple-framework access, and Zig has no relevant app ecosystem.

### Cited Findings
- The official Kotlin MCP SDK is Tier 3. — [MCP SDKs page](https://modelcontextprotocol.io/docs/sdk)

### Inferences
- KMP's value is Android sharing, which is not a requirement here. Flutter and Compose Desktop would need the same Swift shims as Tauri for Foundation Models, App Intents and extensions, with a smaller LLM corpus for desktop use. Zig is only plausible as a tiny native library, and C (SQLite) already covers that.

### Gaps
- No 2026 sources on KMP, Compose or Flutter macOS maturity were fetched.

---

## 9. Recommendation and decision matrix

### Takeaway
Use **Swift 6 / SwiftUI + AppKit as the primary stack** (option A′). Give **TypeScript a tightly scoped second role**: the CodeMirror 6 Markdown editor hosted in a WKWebView, and the Safari Web Extension clipper, which needs JS anyway. **Do not adopt Rust in v1.** Keep it as a planned escape hatch for one hot path (a Tantivy search process) if FTS5 benchmarks fail at 100k notes. Use **Python only offline** (MLX fine-tuning experiments, `apple-fm-sdk` evals), never as a shipped sidecar. Build the **MCP server as a separate Swift executable** (`kb-mcp`) on the shared core package, reading the same SQLite index. If the Tier 3 Swift SDK blocks something, port only that binary to the Tier 1 TypeScript SDK.

### Cited Findings (basis for the recommendation)
- Foundation Models has a first-class Swift API and only a beta Python SDK. Other languages need Swift shims. — [PyPI apple-fm-sdk](https://pypi.org/project/apple-fm-sdk/); [apple-foundation-models](https://pypi.org/project/apple-foundation-models/)
- Swift MCP SDK is Tier 3, TypeScript and Rust are Tier 1. — [MCP SDKs](https://modelcontextprotocol.io/docs/sdk)
- TextKit 2 has large-document performance reports and open bugs. — [Apple forums 729491](https://developer.apple.com/forums/thread/729491); [STTextView](https://www.github.com/krzyzanowskim/STTextView)
- Frontier Claude models now write near-working SwiftUI one-shot (9/10), with known idiom gaps. — [Cocoa with Love](https://cocoawithlove.com/blog/llms-twelve-months-later.html)
- A web-UI hybrid added ~150 MB in Raycast's case, but that included a Node backend. — [Raycast deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)

### Decision matrix (judgment; scores 1–5, weighted to /100)

| Criterion (weight) | A Pure Swift | **A′ Swift + CM6 editor island** | B Rust core + SwiftUI | C Tauri 2 | D Electron | E Swift + Py/TS sidecar | F GPUI |
|---|---|---|---|---|---|---|---|
| Editor quality, live preview, large docs (15) | 3 | **5** | 3* | 5 | 5 | 3 | 3 |
| Apple frameworks: FM, MLX, Spotlight, Intents, extensions (15) | 5 | **5** | 5 | 2 | 1 | 5 | 2 |
| PDF read and annotate (10) | 5 | **5** | 5 | 3 | 4 | 5 | 1 |
| Performance, memory, startup (10) | 5 | **4** | 5 | 4 | 2 | 3 | 5 |
| Search, vector, Markdown ecosystem (10) | 3 | **4** | 5 | 5 | 5 | 4 | 4 |
| MCP SDK maturity (5) | 2 | **2** (TS fallback) | 5 | 5 | 5 | 4 | 5 |
| Agent build/test loop speed and CLI-friendliness (10) | 3 | **4** | 3 | 4 | 5 | 3 | 3 |
| LLM proficiency in the stack (10) | 3 | **4** | 3 | 4 | 5 | 4 | 2 |
| Long-term maintenance and complexity for one dev (10) | 4 | **4** | 2 | 3 | 4 | 2 | 1 |
| iOS companion reuse (5) | 5 | **4** | 5 | 3 | 2 | 3 | 1 |
| **Weighted total /100** | **77** | **86** | **80** | **75** | **75** | **73** | **53** |

\*B with a CM6 editor would score 5 on the editor and ~86 total, but loses on maintenance because of two toolchains and the FFI layer. Only choose it if search or indexing proves CPU-bound in Swift.

Sensitivity: if on-device Apple ML and Apple extensions are dropped (weight → 0), Electron and Tauri rise to about the level of A′. The Swift choice depends on the Apple-integration requirement and should be re-evaluated if that requirement changes.

### Precise roles in the recommended stack
- **Swift 6 (primary, ~85–90% of code).** App shell (SwiftUI with AppKit for windows, menus, sidebar, outline), vault model, FS watching (FSEvents), Markdown + YAML parsing for indexing, SQLite index (GRDB + FTS5 + sqlite-vec extension), embeddings and reranking (Core ML / MLX Swift), Foundation Models, Claude API client, background jobs (Swift concurrency + launchd/XPC helper if out-of-process), PDFKit viewer and annotations, App Intents, Core Spotlight, Share extension, and the `kb-mcp` CLI (stdio MCP server on the same `KBCore` package).
- **TypeScript (scoped, ~10–15%).** A single bundled CodeMirror 6 editor (live preview, wikilinks, embeds) running in WKWebView, with a typed message bridge to Swift (document text in, edits and cursor out, Swift owning file I/O). Also the Safari Web Extension content script for clipping. Built with Vite/pnpm and unit-tested with Vitest, with no Node runtime shipped.
- **Rust (deferred).** Only if a measured FTS5 or vector bottleneck at 100k notes appears: a Tantivy indexer as a separate process (Raycast pattern) or a UniFFI library.
- **Python (dev-time only).** MLX model conversion and fine-tuning, `apple-fm-sdk` batch evals of prompts.

### Main risks and mitigations
1. **Swift agent productivity (outdated idioms, concurrency errors, slower Xcode loop).** Mitigations: keep logic in SwiftPM packages tested via `swift test`; add XcodeBuildMCP or Xcode 26.3 MCP for app-level builds and previews; keep a CLAUDE.md that pins modern idioms; keep Apple docs in context; require a spec before each feature.
2. **Tier 3 Swift MCP SDK.** Mitigations: isolate MCP in its own binary on a stable SQLite and read-API contract; run the official conformance tests; port that binary to the TS SDK if features (OAuth, Streamable HTTP, elicitation) lag.
3. **WKWebView editor integration (IME, undo, accessibility, focus, drag-drop of attachments).** Mitigations: spike in week 1 against a 50k-line file and CJK IME. Keep the bridge narrow (text + selection + commands). Keep a native TextKit 2 / STTextView fallback viable by making the editor a protocol boundary.
4. **TextKit 2 performance, if going fully native (option A).** Mitigation: viewport-only layout, no full `ensureLayout`, a benchmark gate before committing.
5. **Index drift with external edits (git, Obsidian, agents).** This is language-agnostic. Mitigations: Markdown stays canonical, the index is fully rebuildable, content hashes plus FSEvents, and a periodic reconcile.
6. **Lock-in to macOS 26+ APIs.** Acceptable for a one-user app. Gate Foundation Models features behind availability checks.

### Inferences
- Pure-native A is a reasonable second choice if the editor spike shows TextKit 2/STTextView handling the target files smoothly. Then the TS footprint shrinks to the clipper only.
- Tauri and Electron would be right if cross-platform or web reuse were a goal. For a Mac-first, Apple-ML-heavy, single-user app, they put the most valuable integrations behind the hardest boundary.

### Gaps
- Matrix scores are researcher judgment informed by the cited evidence, not measurements.
- UniFFI and swift-bridge maturity and async support in 2026 were not verified this session. Option B's maintenance score rests on general reasoning and the Element X precedent.
- No source verified sqlite-vec loading inside GRDB on macOS (the Swift subsystem researcher may cover this).
