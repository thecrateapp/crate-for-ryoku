import { describe, expect, it } from "vitest";
import type { Mark } from "./camera";
import { redactionsAt, toPixels } from "./redact";

const boxes: [number, number, number, number][] = [[0.776, 0.085, 0.138, 0.03]];
const marks: Mark[] = [
  { t: 2, step: 1, kind: "open", surface: "network", focus: [0.77, 0.02, 0.15, 0.5], redact: boxes },
  { t: 5, step: 2, kind: "close", surface: "network" },
];

describe("redactionsAt", () => {
  it("covers a surface's private boxes for its whole life on screen, with margins", () => {
    expect(redactionsAt(1.5, marks)).toEqual([]);
    expect(redactionsAt(1.95, marks)).toEqual(boxes); // before the panel's first frame
    expect(redactionsAt(3.5, marks)).toEqual(boxes);
    expect(redactionsAt(5.4, marks)).toEqual(boxes); // while it animates out
    expect(redactionsAt(6, marks)).toEqual([]);
  });

  it("covers to the end of the take when the surface never closes", () => {
    expect(redactionsAt(60, [marks[0]])).toEqual(boxes);
  });
});

describe("toPixels", () => {
  it("places a box on the drawn take", () => {
    expect(toPixels([0.5, 0.25, 0.1, 0.1], { left: -100, top: -50, width: 4000, height: 2500 })).toEqual({
      left: 1900,
      top: 575,
      width: 400,
      height: 250,
    });
  });
});
