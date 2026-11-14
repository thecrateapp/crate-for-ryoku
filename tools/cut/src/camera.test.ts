import { describe, expect, it } from "vitest";
import { cameraAt, type Mark } from "./camera";

const launcher: Mark[] = [
  { t: 1, step: 1, kind: "open", surface: "launcher", focus: [0.3, 0.05, 0.4, 0.3] },
  { t: 4, step: 2, kind: "close", surface: "launcher" },
];

describe("cameraAt", () => {
  it("shows the whole output when nothing happens", () => {
    expect(cameraAt(3, [])).toEqual({ scale: 1, x: 0.5, y: 0.5 });
  });

  it("zooms onto a surface while it is open and back out after it closes", () => {
    expect(cameraAt(0.9, launcher).scale).toBe(1);
    const held = cameraAt(2.5, launcher);
    // fits 0.4 x 0.3 with a margin: min(0.85 / 0.4, 0.85 / 0.3) = 2.125
    expect(held.scale).toBeCloseTo(2.125);
    expect(held.x).toBeCloseTo(0.5);
    // the rectangle's centre (0.2) is too close to the top: clamped to 0.5 / 2.125
    expect(held.y).toBeCloseTo(0.5 / 2.125);
    expect(cameraAt(4.9, launcher)).toEqual({ scale: 1, x: 0.5, y: 0.5 });
  });

  it("eases in and out without jumps", () => {
    let previous = cameraAt(0.9, launcher).scale;
    for (let t = 0.9; t <= 5; t += 1 / 60) {
      const scale = cameraAt(t, launcher).scale;
      expect(Math.abs(scale - previous)).toBeLessThan(0.08);
      previous = scale;
    }
  });

  it("never caps above 2.2 for a small surface", () => {
    const small: Mark[] = [{ t: 0, step: 1, kind: "open", surface: "s", focus: [0.45, 0.45, 0.05, 0.05] }];
    expect(cameraAt(2, small).scale).toBeCloseTo(2.2);
  });

  it("punches in a little on a click, then settles back", () => {
    const click: Mark[] = [{ t: 2, step: 1, kind: "click", point: [0.48, 0.01] }];
    const at = cameraAt(2.8, click);
    expect(at.scale).toBeCloseTo(1.25);
    expect(at.y).toBeCloseTo(0.5 / 1.25);
    expect(cameraAt(4, click)).toEqual({ scale: 1, x: 0.5, y: 0.5 });
  });

  it("keeps the surface framing when a click lands inside it", () => {
    const both: Mark[] = [...launcher, { t: 2, step: 3, kind: "click", point: [0.5, 0.2] }];
    expect(cameraAt(2.8, both).scale).toBeCloseTo(2.125);
  });

  it("never shows anything outside the output", () => {
    const marks: Mark[] = [
      { t: 0, step: 1, kind: "open", surface: "s", focus: [0.9, 0.9, 0.1, 0.1] },
      { t: 3, step: 2, kind: "close", surface: "s" },
      { t: 4, step: 3, kind: "click", point: [0, 1] },
    ];
    for (let t = 0; t < 7; t += 0.05) {
      const { scale, x, y } = cameraAt(t, marks);
      const half = 0.5 / scale;
      expect(x - half).toBeGreaterThanOrEqual(-1e-9);
      expect(x + half).toBeLessThanOrEqual(1 + 1e-9);
      expect(y - half).toBeGreaterThanOrEqual(-1e-9);
      expect(y + half).toBeLessThanOrEqual(1 + 1e-9);
    }
  });
});
