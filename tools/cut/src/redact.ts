import type { Mark } from "./camera";

type Box = [number, number, number, number];

/** Blur from just before a surface's first frame until its close animation ends. */
const LEAD = 0.1;
const TAIL = 0.6;

/** The private boxes to blur at time t: every open surface's `redact` boxes. */
export function redactionsAt(t: number, marks: Mark[]): Box[] {
  const out: Box[] = [];
  marks.forEach((mark, i) => {
    if (mark.kind !== "open" || !mark.redact) return;
    const close = marks.slice(i + 1).find((m) => m.kind === "close" && m.surface === mark.surface);
    const until = close ? close.t + TAIL : Number.POSITIVE_INFINITY;
    if (t >= mark.t - LEAD && t <= until) out.push(...mark.redact);
  });
  return out;
}

/** A 0..1 box on the take, in pixels where the take is drawn. */
export function toPixels(box: Box, drawn: { left: number; top: number; width: number; height: number }) {
  const [x, y, w, h] = box;
  return {
    left: drawn.left + x * drawn.width,
    top: drawn.top + y * drawn.height,
    width: w * drawn.width,
    height: h * drawn.height,
  };
}
