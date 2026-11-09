import type { EditorMessage } from "./bridge";

type Pending<T> = { resolve: (value: T) => void; timer: ReturnType<typeof setTimeout> };

/**
 * Request/response over the bridge: the editor sends a message with an id, the host answers
 * with the same id. Unanswered requests resolve to `fallback` after `timeoutMs`, so the editor
 * never waits on a host that is busy or gone.
 */
export class HostRequests {
  private nextID = 1;
  private pending = new Map<number, Pending<unknown>>();

  constructor(
    private readonly send: (message: EditorMessage) => void,
    private readonly timeoutMs = 1500,
  ) {}

  request<T>(build: (id: number) => EditorMessage, fallback: T): Promise<T> {
    const id = this.nextID++;
    return new Promise<T>((resolve) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        resolve(fallback);
      }, this.timeoutMs);
      this.pending.set(id, { resolve: resolve as (value: unknown) => void, timer });
      this.send(build(id));
    });
  }

  /** Delivers a host answer. Unknown or late ids are ignored. */
  answer(id: number, value: unknown): void {
    const entry = this.pending.get(id);
    if (!entry) return;
    clearTimeout(entry.timer);
    this.pending.delete(id);
    entry.resolve(value);
  }

  get outstanding(): number {
    return this.pending.size;
  }
}
