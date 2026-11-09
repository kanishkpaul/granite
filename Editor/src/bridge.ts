// The typed message channel between granite's Swift host and this editor.
// Mirror: App/Bridges/EditorBridge.swift. Change both together; test/fixtures/bridge-messages.json
// is decoded and re-encoded by both sides (Vitest and the Swift round-trip test).
//
// Swift owns all file I/O. The editor receives text and decoration data and sends back
// debounced text changes, the selection, and link activations.

export const PROTOCOL_VERSION = 1;

export type EditorCommand = "undo" | "redo" | "focus" | "selectAll";

/** Host → editor. Delivered through `window.granite.receive(message)`. */
export type HostMessage =
  | { type: "load"; path: string; text: string; version: number; cursor?: number }
  | { type: "setResolved"; targets: string[] }
  | { type: "command"; name: EditorCommand }
  | { type: "bench"; lines: number[]; keystrokes: number; scrollMs: number };

export interface BenchResult {
  /** Ms per keystroke right after jumping to a position: sync dispatch plus CodeMirror's next-frame work. */
  typing: number[];
  /** Same, after the syntax tree has been parsed up to the position. */
  parsedTyping: number[];
  /** Ms to parse up to each typed position (the work cold keystrokes pay in 20 ms slices). */
  parseMs: number[];
  /** Same, but typed through the contenteditable (execCommand), like real input. */
  domTyping: number[];
  /** Frame-to-frame intervals while scrolling top to bottom. */
  scrollFrames: number[];
  undoRestored: boolean;
  redoReapplied: boolean;
  docLines: number;
}

/** Editor → host. Posted to `webkit.messageHandlers.granite`. */
export type EditorMessage =
  | { type: "ready"; protocol: number }
  | { type: "loaded"; version: number; ms: number }
  | { type: "changed"; version: number; text: string }
  | { type: "selection"; anchor: number; head: number; line: number }
  | { type: "openLink"; target: string; heading?: string; blockID?: string; newPane: boolean }
  | { type: "benchResult"; result: BenchResult }
  | { type: "log"; level: "info" | "error"; message: string };

export class BridgeError extends Error {}

type Shape = Record<string, "string" | "number" | "boolean" | "string[]" | "number[]" | "string?" | "number?">;

const hostShapes: Record<HostMessage["type"], Shape> = {
  load: { path: "string", text: "string", version: "number", cursor: "number?" },
  setResolved: { targets: "string[]" },
  command: { name: "string" },
  bench: { lines: "number[]", keystrokes: "number", scrollMs: "number" },
};

const commands: readonly EditorCommand[] = ["undo", "redo", "focus", "selectAll"];

function check(value: Record<string, unknown>, shape: Shape, context: string): void {
  for (const [key, kind] of Object.entries(shape)) {
    const field = value[key];
    const optional = kind.endsWith("?");
    if (field === undefined) {
      if (optional) continue;
      throw new BridgeError(`${context}: missing ${key}`);
    }
    const base = optional ? kind.slice(0, -1) : kind;
    const ok =
      base === "string[]"
        ? Array.isArray(field) && field.every((item) => typeof item === "string")
        : base === "number[]"
          ? Array.isArray(field) && field.every((item) => typeof item === "number")
          : typeof field === base;
    if (!ok) throw new BridgeError(`${context}: ${key} should be ${kind}`);
  }
}

/** Validates an incoming host message. Throws `BridgeError` on anything malformed. */
export function parseHostMessage(raw: unknown): HostMessage {
  const value = typeof raw === "string" ? (JSON.parse(raw) as unknown) : raw;
  if (typeof value !== "object" || value === null) throw new BridgeError("message is not an object");
  const record = value as Record<string, unknown>;
  const type = record.type;
  if (typeof type !== "string" || !(type in hostShapes)) throw new BridgeError(`unknown message type ${String(type)}`);
  check(record, hostShapes[type as HostMessage["type"]], type);
  if (type === "command" && !commands.includes(record.name as EditorCommand)) {
    throw new BridgeError(`unknown command ${String(record.name)}`);
  }
  return record as unknown as HostMessage;
}

interface WebKitWindow {
  webkit?: { messageHandlers?: { granite?: { postMessage(message: unknown): void } } };
}

/** Sends to the Swift host; outside WKWebView (tests, browser dev) it goes to `fallback`. */
export function post(message: EditorMessage, fallback?: (message: EditorMessage) => void): void {
  const handler = (globalThis as unknown as WebKitWindow).webkit?.messageHandlers?.granite;
  if (handler) handler.postMessage(message);
  else fallback?.(message);
}
