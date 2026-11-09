import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { BridgeError, parseHostMessage } from "../src/bridge";

const fixtures = JSON.parse(readFileSync(join(process.cwd(), "test/fixtures/bridge-messages.json"), "utf8")) as {
  host: unknown[];
  editor: unknown[];
  invalidHost: unknown[];
};

describe("bridge protocol", () => {
  it("accepts every host fixture and round-trips it unchanged", () => {
    for (const message of fixtures.host) {
      const parsed = parseHostMessage(JSON.stringify(message));
      expect(JSON.parse(JSON.stringify(parsed))).toEqual(message);
    }
  });

  it("rejects malformed host messages", () => {
    for (const message of fixtures.invalidHost) {
      expect(() => parseHostMessage(message), JSON.stringify(message)).toThrow();
    }
    expect(() => parseHostMessage({ type: "command", name: "x" })).toThrow(BridgeError);
  });

  it("has an editor fixture for every editor message type", () => {
    const types = new Set(fixtures.editor.map((m) => (m as { type: string }).type));
    expect([...types].sort()).toEqual(["benchResult", "changed", "loaded", "log", "openLink", "ready", "selection"]);
  });
});
