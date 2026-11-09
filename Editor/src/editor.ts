import { closeBrackets } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap, indentWithTab, redo, redoDepth, undo, undoDepth } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { bracketMatching, forceParsing, indentOnInput } from "@codemirror/language";
import { highlightSelectionMatches, searchKeymap } from "@codemirror/search";
import { EditorSelection, EditorState, type Extension } from "@codemirror/state";
import { drawSelection, EditorView, highlightActiveLine, keymap, rectangularSelection } from "@codemirror/view";
import { type BenchResult, type EditorMessage, type HostMessage, parseHostMessage, post, PROTOCOL_VERSION } from "./bridge";
import { livePreview, resolvedTargets, setResolvedEffect } from "./livePreview";
import { theme } from "./theme";
import { obsidianSyntax, parseTarget } from "./wikilink";

export interface GraniteEditorOptions {
  parent: HTMLElement;
  /** Where messages go outside WKWebView (browser dev, tests). */
  fallback?: (message: EditorMessage) => void;
  /** Debounce for `changed` messages, in ms. */
  changeDelay?: number;
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

  constructor(options: GraniteEditorOptions) {
    this.fallback = options.fallback;
    this.changeDelay = options.changeDelay ?? 250;
    this.view = new EditorView({ parent: options.parent, state: this.makeState("") });
    this.send({ type: "ready", protocol: PROTOCOL_VERSION });
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
      theme,
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
      EditorView.updateListener.of((update) => {
        if (this.loading) return;
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
    }
  }

  private load(text: string, version: number, path: string, cursor?: number): void {
    const start = performance.now();
    this.flush();
    this.loading = true;
    const resolved = this.view.state.field(resolvedTargets, false) ?? null;
    this.view.setState(this.makeState(text, cursor ?? 0));
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
