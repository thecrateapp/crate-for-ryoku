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

describe("framing below full size", () => {
  it("centres a smaller-than-frame screen (the 3D intro and outro)", () => {
    const f = framing({ scale: 0.8, x: 0.5, y: 0.5 }, SRC, OUT);
    expect(f.left).toBeCloseTo((1920 - f.width) / 2);
    expect(f.top).toBeCloseTo((1080 - f.height) / 2);
  });
});

describe("framing for a vertical cut", () => {
  // The same 3840 x 2400 take cut to 1080 x 1920 (9:16).
  const PORTRAIT = { width: 1080, height: 1920 };

  it("covers the portrait frame height-bound at scale 1, centred on the camera", () => {
    const f = framing({ scale: 1, x: 0.5, y: 0.5 }, SRC, PORTRAIT);
    expect(f.height).toBeCloseTo(1920);
    expect(f.width).toBeCloseTo(3072);
    expect(f.top).toBeCloseTo(0);
    expect(f.left + 0.5 * f.width).toBeCloseTo(540);
  });

  it("keeps the camera centre in the middle when it can, and never shows an empty edge", () => {
    const mid = framing({ scale: 1.6, x: 0.4, y: 0.5 }, SRC, PORTRAIT);
    expect(mid.left + 0.4 * mid.width).toBeCloseTo(540);
    expect(mid.top + 0.5 * mid.height).toBeCloseTo(960);
    for (const x of [0, 0.1, 0.5, 0.9, 1]) {
      for (const scale of [1, 1.3, 2.2]) {
        const f = framing({ scale, x, y: 1 - x }, SRC, PORTRAIT);
        expect(f.left).toBeLessThanOrEqual(0);
        expect(f.top).toBeLessThanOrEqual(1e-9);
        expect(f.left + f.width).toBeGreaterThanOrEqual(PORTRAIT.width - 1e-9);
        expect(f.top + f.height).toBeGreaterThanOrEqual(PORTRAIT.height - 1e-9);
      }
    }
  });
});
