import { closeBrackets } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap, indentWithTab, redo, redoDepth, undo, undoDepth } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { bracketMatching, forceParsing, indentOnInput } from "@codemirror/language";
import { highlightSelectionMatches, searchKeymap } from "@codemirror/search";
import { Annotation, EditorSelection, EditorState, type Extension, StateEffect, StateField } from "@codemirror/state";
import { drawSelection, EditorView, highlightActiveLine, keymap, type Panel, rectangularSelection, showPanel } from "@codemirror/view";
import { type BenchResult, type CompletionItem, type EditorMessage, type HostMessage, parseHostMessage, post, PROTOCOL_VERSION } from "./bridge";
import { graniteCompletion } from "./completion";
import { frontmatterFold, frontmatterRange } from "./frontmatter";
import { HostRequests } from "./hostRequests";
import { type EmbedContent, embedResolver, livePreview, resolvedTargets, setResolvedEffect } from "./livePreview";
import { theme } from "./theme";
import { obsidianSyntax, parseTarget } from "./wikilink";

/** Marks transactions that apply the on-disk version: they are not local edits and are never sent back. */
const fromDisk = Annotation.define<boolean>();

const setBanner = StateEffect.define<string | null>();
/** Text of a pending on-disk version while the editor has unsaved edits; drives the banner panel. */
const externalBanner = StateField.define<string | null>({
  create: () => null,
  update(value, transaction) {
    for (const effect of transaction.effects) if (effect.is(setBanner)) return effect.value;
    return value;
  },
});

/** Common prefix/suffix diff, so applying the disk version keeps the cursor and undo history. */
export function minimalChange(current: string, next: string): { from: number; to: number; insert: string } | null {
  if (current === next) return null;
  let start = 0;
  const shorter = Math.min(current.length, next.length);
  while (start < shorter && current.charCodeAt(start) === next.charCodeAt(start)) start++;
  let endCurrent = current.length;
  let endNext = next.length;
  while (endCurrent > start && endNext > start && current.charCodeAt(endCurrent - 1) === next.charCodeAt(endNext - 1)) {
    endCurrent--;
    endNext--;
  }
  return { from: start, to: endCurrent, insert: next.slice(start, endNext) };
}

export interface GraniteEditorOptions {
  parent: HTMLElement;
  /** Where messages go outside WKWebView (browser dev, tests). */
  fallback?: (message: EditorMessage) => void;
  /** Debounce for `changed` messages, in ms. */
  changeDelay?: number;
  /** How long to wait for host answers (completions, embeds), in ms. */
  requestTimeout?: number;
}

export class GraniteEditor {
  readonly view: EditorView;
  private version = 0;
  private path = "";
  private changeTimer: ReturnType<typeof setTimeout> | undefined;
  private selectionTimer: ReturnType<typeof setTimeout> | undefined;
  private readonly fallback?: (message: EditorMessage) => void;
  private readonly changeDelay: number;
  private loading = false;
  private readonly requests: HostRequests;
  private embedCache = new Map<string, Promise<EmbedContent>>();

  constructor(options: GraniteEditorOptions) {
    this.fallback = options.fallback;
    this.changeDelay = options.changeDelay ?? 250;
    this.requests = new HostRequests((message) => this.send(message), options.requestTimeout ?? 1500);
    this.view = new EditorView({ parent: options.parent, state: this.makeState("") });
    this.send({ type: "ready", protocol: PROTOCOL_VERSION });
  }

  /** Link and tag completions, answered by the host from the index. */
  complete(kind: "link" | "tag", query: string): Promise<CompletionItem[]> {
    return this.requests.request<CompletionItem[]>((id) => ({ type: "complete", id, kind, query }), []);
  }

  /** Embed content, asked once per target per loaded note. */
  resolveEmbed(target: string): Promise<EmbedContent> {
    let pending = this.embedCache.get(target);
    if (!pending) {
      pending = this.requests.request<EmbedContent>((id) => ({ type: "resolveEmbed", id, target }), { kind: "missing" });
      this.embedCache.set(target, pending);
    }
    return pending;
  }

  /** True while a local edit hasn't been sent to the host yet. */
  get hasUnsentChanges(): boolean {
    return this.changeTimer !== undefined;
  }

  private extensions(): Extension[] {
    return [
      history(),
      drawSelection(),
      rectangularSelection(),
      indentOnInput(),
      bracketMatching(),
      closeBrackets(),
      highlightActiveLine(),
      highlightSelectionMatches(),
      EditorView.lineWrapping,
      markdown({ base: markdownLanguage, extensions: [obsidianSyntax] }),
      resolvedTargets,
      livePreview,
      frontmatterFold,
      embedResolver.of((target) => this.resolveEmbed(target)),
      graniteCompletion((kind, query) => this.complete(kind, query)),
      externalBanner,
      showPanel.from(externalBanner, (text) => (text === null ? null : (view) => this.bannerPanel(view))),
      theme,
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
      EditorView.updateListener.of((update) => {
        if (this.loading) return;
        if (update.transactions.some((tr) => tr.annotation(fromDisk))) return;
        if (update.docChanged) {
          this.version += 1;
          this.scheduleChanged();
        }
        if (update.selectionSet) this.scheduleSelection();
      }),
      EditorView.domEventHandlers({
        mousedown: (event, view) => this.handleLinkClick(event, view),
      }),
    ];
  }

  private makeState(text: string, cursor = 0): EditorState {
    return EditorState.create({
      doc: text,
      selection: EditorSelection.cursor(Math.min(cursor, text.length)),
      extensions: this.extensions(),
    });
  }

  private send(message: EditorMessage): void {
    post(message, this.fallback);
  }

  /** Entry point for the host: accepts a message object or its JSON. */
  receive(raw: unknown): void {
    let message: HostMessage;
    try {
      message = parseHostMessage(raw);
    } catch (error) {
      this.send({ type: "log", level: "error", message: String(error) });
      return;
    }
    switch (message.type) {
      case "load":
        this.load(message.text, message.version, message.path, message.cursor);
        break;
      case "setResolved":
        this.view.dispatch({ effects: setResolvedEffect.of(new Set(message.targets.map((t) => t.toLowerCase()))) });
        break;
      case "command":
        this.command(message.name);
        break;
      case "bench":
        void runBench(this, message).then((result) => this.send({ type: "benchResult", result }));
        break;
      case "completions":
        this.requests.answer(message.id, message.items);
        break;
      case "embed":
        this.requests.answer(message.id, {
          kind: message.kind, title: message.title, text: message.text, dataURL: message.dataURL,
        } satisfies EmbedContent);
        break;
      case "external":
        this.external(message.path, message.text);
        break;
    }
  }

  /** The open note changed on disk. Unsaved local edits get a choice; otherwise apply quietly. */
  private external(path: string, text: string): void {
    if (path !== this.path) return;
    if (text === this.view.state.doc.toString()) return;
    if (this.hasUnsentChanges) {
      this.view.dispatch({ effects: setBanner.of(text) });
      return;
    }
    this.applyDiskVersion(text);
  }

  private applyDiskVersion(text: string): void {
    const change = minimalChange(this.view.state.doc.toString(), text);
    this.view.dispatch({
      changes: change ?? [],
      effects: setBanner.of(null),
      annotations: [fromDisk.of(true)],
    });
    this.embedCache.clear();
  }

  private bannerPanel(view: EditorView): Panel {
    const dom = document.createElement("div");
    dom.className = "cm-external-banner";
    const label = document.createElement("span");
    label.textContent = "This note changed on disk while you were editing.";
    const keep = document.createElement("button");
    keep.textContent = "Keep mine";
    keep.onclick = () => {
      view.dispatch({ effects: setBanner.of(null) });
      this.flush();
    };
    const take = document.createElement("button");
    take.textContent = "Take theirs";
    take.onclick = () => {
      const text = view.state.field(externalBanner);
      clearTimeout(this.changeTimer);
      this.changeTimer = undefined;
      if (text !== null) this.applyDiskVersion(text);
    };
    dom.append(label, keep, take);
    return { dom, top: true };
  }

  private load(text: string, version: number, path: string, cursor?: number): void {
    const start = performance.now();
    this.flush();
    this.loading = true;
    const resolved = this.view.state.field(resolvedTargets, false) ?? null;
    this.embedCache.clear();
    this.view.setState(this.makeState(text, cursor ?? 0));
    // Opening at the top: start in the body so the frontmatter stays folded.
    if (!cursor) {
      const yaml = frontmatterRange(this.view.state);
      if (yaml && yaml.to < this.view.state.doc.length) {
        this.view.dispatch({ selection: { anchor: yaml.to + 1 }, annotations: [fromDisk.of(true)] });
      }
    }
    if (resolved) this.view.dispatch({ effects: setResolvedEffect.of(resolved) });
    this.loading = false;
    this.version = version;
    this.path = path;
    // Report after the first frame has laid out and painted.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => this.send({ type: "loaded", version, ms: performance.now() - start }));
    });
  }

  command(name: "undo" | "redo" | "focus" | "selectAll"): void {
    switch (name) {
      case "undo":
        undo(this.view);
        break;
      case "redo":
        redo(this.view);
        break;
      case "focus":
        this.view.focus();
        break;
      case "selectAll":
        this.view.dispatch({ selection: EditorSelection.single(0, this.view.state.doc.length) });
        break;
    }
  }

  get canUndo(): boolean {
    return undoDepth(this.view.state) > 0;
  }

  get canRedo(): boolean {
    return redoDepth(this.view.state) > 0;
  }

  get currentPath(): string {
    return this.path;
  }

  private scheduleChanged(): void {
    clearTimeout(this.changeTimer);
    this.changeTimer = setTimeout(() => this.flush(), this.changeDelay);
  }

  /** Sends any pending change now (before a load, or when the host asks to save). */
  flush(): void {
    if (this.changeTimer === undefined) return;
    clearTimeout(this.changeTimer);
    this.changeTimer = undefined;
    this.send({ type: "changed", version: this.version, text: this.view.state.doc.toString() });
  }

  private scheduleSelection(): void {
    clearTimeout(this.selectionTimer);
    this.selectionTimer = setTimeout(() => {
      const range = this.view.state.selection.main;
      this.send({
        type: "selection",
        anchor: range.anchor,
        head: range.head,
        line: this.view.state.doc.lineAt(range.head).number,
      });
    }, 100);
  }

  /** ⌘-click on a wikilink opens it (⌘⌥-click in a new pane), like Obsidian. */
  private handleLinkClick(event: MouseEvent, _view: EditorView): boolean {
    if (!event.metaKey) return false;
    const element = (event.target as HTMLElement | null)?.closest<HTMLElement>("[data-target]");
    if (!element) return false;
    const target = parseTarget(element.dataset.target ?? "");
    event.preventDefault();
    this.send({ type: "openLink", ...target, newPane: event.altKey });
    return true;
  }
}

// MARK: - Benchmark (spike A gates)

function nextFrame(): Promise<number> {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

/**
 * Per keystroke: time to dispatch, plus the time CodeMirror's own measure/paint work takes in the
 * next frame. A frame callback registered before the keystroke runs before CodeMirror's; one
 * registered after runs after it, so the gap between them is CodeMirror's frame work.
 */
async function measureKeystroke(type: () => void): Promise<number> {
  let frameStart = 0;
  requestAnimationFrame((time) => {
    frameStart = performance.now();
    void time;
  });
  const start = performance.now();
  type();
  // DOM input reaches CodeMirror through a MutationObserver callback (a microtask): let it run.
  await Promise.resolve();
  const dispatchMs = performance.now() - start;
  await nextFrame();
  const frameMs = performance.now() - frameStart;
  return dispatchMs + frameMs;
}

export async function runBench(
  editor: GraniteEditor,
  options: { lines: number[]; keystrokes: number; scrollMs: number },
): Promise<BenchResult> {
  const view = editor.view;
  const typing: number[] = [];
  const parsedTyping: number[] = [];
  const parseMs: number[] = [];
  const domTyping: number[] = [];
  const typeAtCursor = () => {
    const head = view.state.selection.main.head;
    view.dispatch({ changes: { from: head, insert: "x" }, selection: { anchor: head + 1 }, userEvent: "input.type" });
  };
  const docLines = view.state.doc.lines;
  const startDoc = view.state.doc.toString();

  for (const requested of options.lines) {
    const lineNumber = Math.max(1, Math.min(requested, view.state.doc.lines));
    const line = view.state.doc.line(lineNumber);
    view.dispatch({ selection: { anchor: line.to }, scrollIntoView: true });
    view.focus();
    await nextFrame();
    await nextFrame();
    for (let i = 0; i < options.keystrokes; i++) typing.push(await measureKeystroke(typeAtCursor));
    const parseStart = performance.now();
    forceParsing(view, view.state.doc.lineAt(view.state.selection.main.head).to, 30_000);
    parseMs.push(performance.now() - parseStart);
    await nextFrame();
    for (let i = 0; i < options.keystrokes; i++) parsedTyping.push(await measureKeystroke(typeAtCursor));
    for (let i = 0; i < options.keystrokes; i++) {
      // Goes through the contenteditable and CodeMirror's DOM observer, like real typing.
      domTyping.push(await measureKeystroke(() => document.execCommand("insertText", false, "y")));
    }
  }

  // Undo everything typed, then redo it, across the same command path the host uses.
  while (editor.canUndo) editor.command("undo");
  const undoRestored = view.state.doc.toString() === startDoc;
  let redone = 0;
  while (editor.canRedo && redone < 10_000) {
    editor.command("redo");
    redone++;
  }
  const redoReapplied = view.state.doc.length === startDoc.length + 3 * options.keystrokes * options.lines.length;
  while (editor.canUndo) editor.command("undo");

  // Scroll top to bottom at constant speed; record frame intervals.
  const scrollFrames: number[] = [];
  const scroller = view.scrollDOM;
  scroller.scrollTop = 0;
  await nextFrame();
  const total = scroller.scrollHeight - scroller.clientHeight;
  const startTime = performance.now();
  let last = startTime;
  while (true) {
    const now = await nextFrame();
    const elapsed = now - startTime;
    scrollFrames.push(now - last);
    last = now;
    if (elapsed >= options.scrollMs) break;
    scroller.scrollTop = (total * elapsed) / options.scrollMs;
  }
  scrollFrames.shift();

  return { typing, parsedTyping, parseMs, domTyping, scrollFrames, undoRestored, redoReapplied, docLines };
}
