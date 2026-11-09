import { CompletionContext } from "@codemirror/autocomplete";
import { EditorSelection, EditorState } from "@codemirror/state";
import { describe, expect, it, vi } from "vitest";
import type { CompletionItem, EditorMessage } from "../src/bridge";
import { linkCompletions, linkTrigger, tagCompletions, tagTrigger } from "../src/completion";
import { GraniteEditor, minimalChange } from "../src/editor";
import { frontmatterFold, frontmatterRange, summarize } from "../src/frontmatter";
import { HostRequests } from "../src/hostRequests";

describe("frontmatter fold", () => {
  const doc = "---\ntype: claim\nstatus: held\nconfidence: 0.7\n---\nBody text";

  it("finds the YAML block and summarizes it", () => {
    const state = EditorState.create({ doc });
    const range = frontmatterRange(state);
    expect(range?.to).toBe(doc.indexOf("Body") - 1);
    expect(summarize(range?.body ?? "")).toBe("type: claim · status: held · 3 properties");
    expect(frontmatterRange(EditorState.create({ doc: "no yaml\n---\n" }))).toBeNull();
    expect(frontmatterRange(EditorState.create({ doc: "---\nunclosed: yes\n" }))).toBeNull();
  });

  it("folds only while the cursor is outside it", () => {
    const outside = EditorState.create({ doc, selection: EditorSelection.cursor(doc.length), extensions: [frontmatterFold] });
    expect(outside.field(frontmatterFold).size).toBe(1);
    const inside = outside.update({ selection: { anchor: 6 } }).state;
    expect(inside.field(frontmatterFold).size).toBe(0);
  });
});

describe("completion triggers", () => {
  it("matches [[ links and #tags", () => {
    expect(linkTrigger.exec("see [[Hybr")?.[1]).toBe("Hybr");
    expect(linkTrigger.exec("see [[Note|alias")).toBeNull();
    expect(linkTrigger.exec("see [[Note#Head")).toBeNull();
    expect(tagTrigger.exec("text #retr")?.[1]).toBe("retr");
    expect(tagTrigger.exec("#start")?.[1]).toBe("start");
    expect(tagTrigger.exec("a#b")).toBeNull();
  });

  it("asks the host with the typed query and maps its items", async () => {
    const calls: [string, string][] = [];
    const provider = async (kind: "link" | "tag", query: string): Promise<CompletionItem[]> => {
      calls.push([kind, query]);
      return [{ label: "Hybrid search", apply: "Hybrid retrieval", detail: "alias" }];
    };
    const state = EditorState.create({ doc: "see [[hyb" });
    const result = await linkCompletions(provider)(new CompletionContext(state, state.doc.length, false));
    expect(calls).toEqual([["link", "hyb"]]);
    expect(result?.from).toBe(6);
    expect(result?.options.map((o) => o.label)).toEqual(["Hybrid search"]);
    const tagState = EditorState.create({ doc: "x #ret" });
    const tags = await tagCompletions(provider)(new CompletionContext(tagState, tagState.doc.length, false));
    expect(calls.at(-1)).toEqual(["tag", "ret"]);
    expect(tags?.from).toBe(3);
  });
});

describe("opening a note", () => {
  it("starts in the body so the frontmatter is folded", () => {
    const parent = document.createElement("div");
    document.body.appendChild(parent);
    const editor = new GraniteEditor({ parent });
    editor.receive({ type: "load", path: "a.md", text: "---\ntype: note\n---\nBody", version: 1 });
    expect(editor.view.state.selection.main.head).toBe(19);
    expect(editor.view.state.field(frontmatterFold).size).toBe(1);
    editor.receive({ type: "load", path: "b.md", text: "---\ntype: note\n---\nBody", version: 1, cursor: 5 });
    expect(editor.view.state.selection.main.head).toBe(5);
  });
});

describe("host requests", () => {
  it("resolves on answer and falls back on timeout", async () => {
    vi.useFakeTimers();
    const sent: EditorMessage[] = [];
    const requests = new HostRequests((m) => sent.push(m), 100);
    const answered = requests.request<string[]>((id) => ({ type: "complete", id, kind: "link", query: "a" }), []);
    const ignored = requests.request<string[]>((id) => ({ type: "complete", id, kind: "link", query: "b" }), ["fallback"]);
    requests.answer(1, ["x"]);
    requests.answer(99, ["unknown id"]);
    vi.advanceTimersByTime(150);
    expect(await answered).toEqual(["x"]);
    expect(await ignored).toEqual(["fallback"]);
    expect(requests.outstanding).toBe(0);
    expect(sent.map((m) => (m.type === "complete" ? m.id : -1))).toEqual([1, 2]);
    vi.useRealTimers();
  });
});

describe("minimal change", () => {
  it("replaces only the differing middle", () => {
    expect(minimalChange("hello world", "hello brave world")).toEqual({ from: 6, to: 6, insert: "brave " });
    expect(minimalChange("abc", "abc")).toBeNull();
    expect(minimalChange("abcdef", "abXef")).toEqual({ from: 2, to: 4, insert: "X" });
  });
});

describe("external changes", () => {
  function make() {
    const sent: EditorMessage[] = [];
    const parent = document.createElement("div");
    document.body.appendChild(parent);
    const editor = new GraniteEditor({ parent, fallback: (m) => sent.push(m), changeDelay: 50, requestTimeout: 50 });
    editor.receive({ type: "load", path: "Notes/a.md", text: "line one\nline two\n", version: 1, cursor: 4 });
    return { editor, sent };
  }
  const changed = (sent: EditorMessage[]) => sent.filter((m) => m.type === "changed");

  it("applies a clean disk change quietly, keeping undo, and never echoes it back", () => {
    vi.useFakeTimers();
    const { editor, sent } = make();
    editor.receive({ type: "external", path: "Notes/a.md", text: "line one\nline two edited\n" });
    expect(editor.view.state.doc.toString()).toBe("line one\nline two edited\n");
    expect(editor.view.state.selection.main.head).toBe(4);
    vi.advanceTimersByTime(200);
    expect(changed(sent)).toEqual([]);
    editor.receive({ type: "external", path: "Notes/other.md", text: "ignored" });
    expect(editor.view.state.doc.toString()).toContain("edited");
    vi.useRealTimers();
  });

  it("asks when there are unsent edits: take theirs discards, keep mine saves", () => {
    vi.useFakeTimers();
    const { editor, sent } = make();
    editor.view.dispatch({ changes: { from: 0, insert: "MINE " } });
    editor.receive({ type: "external", path: "Notes/a.md", text: "THEIRS\n" });
    const banner = editor.view.dom.querySelector(".cm-external-banner");
    expect(banner).not.toBeNull();
    const [keep, take] = Array.from(banner?.querySelectorAll("button") ?? []);
    take?.click();
    expect(editor.view.state.doc.toString()).toBe("THEIRS\n");
    vi.advanceTimersByTime(200);
    expect(changed(sent)).toEqual([]);

    editor.view.dispatch({ changes: { from: 0, insert: "MINE " } });
    editor.receive({ type: "external", path: "Notes/a.md", text: "THEIRS AGAIN\n" });
    const again = editor.view.dom.querySelector(".cm-external-banner");
    (again?.querySelectorAll("button")[0] as HTMLButtonElement | undefined)?.click();
    expect(changed(sent).at(-1)).toMatchObject({ text: "MINE THEIRS\n" });
    expect(editor.view.dom.querySelector(".cm-external-banner")).toBeNull();
    void keep;
    vi.useRealTimers();
  });

  it("asks the host for embeds once per target", async () => {
    const { editor, sent } = make();
    const first = editor.resolveEmbed("Diagram.png");
    const second = editor.resolveEmbed("Diagram.png");
    const request = sent.find((m) => m.type === "resolveEmbed");
    expect(sent.filter((m) => m.type === "resolveEmbed")).toHaveLength(1);
    if (request?.type === "resolveEmbed") {
      editor.receive({ type: "embed", id: request.id, target: "Diagram.png", kind: "image", dataURL: "data:image/png;base64,AA==" });
    }
    expect(await first).toMatchObject({ kind: "image" });
    expect(await second).toMatchObject({ kind: "image" });
  });
});
