// jsdom has no layout. CodeMirror measures text in animation frames; give Range the
// rect methods it calls so measurement runs (with zero sizes) instead of throwing.
const empty = { length: 0, item: () => null, [Symbol.iterator]: function* () {} } as unknown as DOMRectList;
const rect = { x: 0, y: 0, width: 0, height: 0, top: 0, left: 0, right: 0, bottom: 0, toJSON: () => ({}) } as DOMRect;
Range.prototype.getClientRects = () => empty;
Range.prototype.getBoundingClientRect = () => rect;
