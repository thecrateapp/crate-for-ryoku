import { describe, expect, it } from "vitest";
import { framing } from "./framing";

// A 3840 x 2400 (16:10) take cut to 1920 x 1080 (16:9).
const SRC = { width: 3840, height: 2400 };
const OUT = { width: 1920, height: 1080 };

describe("framing", () => {
  it("covers the 16:9 frame at scale 1, trimming top and bottom evenly", () => {
    expect(framing({ scale: 1, x: 0.5, y: 0.5 }, SRC, OUT)).toEqual({ width: 1920, height: 1200, left: 0, top: -60 });
  });

  it("puts the camera centre in the middle of the frame when zoomed", () => {
    const f = framing({ scale: 2, x: 0.5, y: 0.5 }, SRC, OUT);
    expect(f.width).toBe(3840);
    expect(f.left + 0.5 * f.width).toBeCloseTo(960);
    expect(f.top + 0.5 * f.height).toBeCloseTo(540);
  });

  it("never leaves an empty edge, even at the top of the take", () => {
    for (const y of [0, 0.1, 0.5, 0.9, 1]) {
      for (const scale of [1, 1.3, 2.2]) {
        const f = framing({ scale, x: y, y }, SRC, OUT);
        expect(f.left).toBeLessThanOrEqual(0);
        expect(f.top).toBeLessThanOrEqual(0);
        expect(f.left + f.width).toBeGreaterThanOrEqual(OUT.width - 1e-9);
        expect(f.top + f.height).toBeGreaterThanOrEqual(OUT.height - 1e-9);
      }
    }
  });
});
