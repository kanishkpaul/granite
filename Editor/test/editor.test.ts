import { describe, expect, it, vi } from "vitest";
import type { EditorMessage } from "../src/bridge";
import { GraniteEditor } from "../src/editor";

function make() {
  const sent: EditorMessage[] = [];
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  const editor = new GraniteEditor({ parent, fallback: (m) => sent.push(m), changeDelay: 10 });
  return { editor, sent };
}

describe("editor host contract", () => {
  it("announces readiness with the protocol version", () => {
    const { sent } = make();
    expect(sent[0]).toEqual({ type: "ready", protocol: 3 });
  });

  it("loads text without reporting it as a change, then debounces real edits", async () => {
    vi.useFakeTimers();
    const { editor, sent } = make();
    editor.receive({ type: "load", path: "Notes/a.md", text: "hello", version: 7 });
    vi.advanceTimersByTime(50);
    expect(sent.filter((m) => m.type === "changed")).toEqual([]);
    editor.view.dispatch({ changes: { from: 5, insert: " world" } });
    editor.view.dispatch({ changes: { from: 11, insert: "!" } });
    vi.advanceTimersByTime(50);
    expect(sent.filter((m) => m.type === "changed")).toEqual([{ type: "changed", version: 9, text: "hello world!" }]);
    vi.useRealTimers();
  });

  it("undo and redo commands from the host cross the bridge", () => {
    const { editor } = make();
    editor.receive({ type: "load", path: "a.md", text: "abc", version: 1 });
    editor.view.dispatch({ changes: { from: 3, insert: "d" } });
    editor.receive(JSON.stringify({ type: "command", name: "undo" }));
    expect(editor.view.state.doc.toString()).toBe("abc");
    editor.receive({ type: "command", name: "redo" });
    expect(editor.view.state.doc.toString()).toBe("abcd");
  });

  it("a new load resets undo history so it cannot undo into another note", () => {
    const { editor } = make();
    editor.receive({ type: "load", path: "a.md", text: "first", version: 1 });
    editor.view.dispatch({ changes: { from: 0, insert: "x" } });
    editor.receive({ type: "load", path: "b.md", text: "second", version: 1 });
    editor.receive({ type: "command", name: "undo" });
    expect(editor.view.state.doc.toString()).toBe("second");
  });

  it("flushes a pending change before loading another note", () => {
    const { editor, sent } = make();
    editor.receive({ type: "load", path: "a.md", text: "a", version: 1 });
    editor.view.dispatch({ changes: { from: 1, insert: "b" } });
    editor.receive({ type: "load", path: "b.md", text: "other", version: 1 });
    expect(sent.filter((m) => m.type === "changed")).toEqual([{ type: "changed", version: 2, text: "ab" }]);
  });

  it("reports malformed host messages instead of throwing", () => {
    const { editor, sent } = make();
    editor.receive({ type: "load" });
    expect(sent.at(-1)).toMatchObject({ type: "log", level: "error" });
  });
});
