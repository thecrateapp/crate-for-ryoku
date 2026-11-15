import { describe, expect, it } from "vitest";
import { BASE, cameraAt, INTRO, type Mark } from "./camera";

const open = (t: number, surface: string, focus: [number, number, number, number]): Mark => ({
  t,
  step: 0,
  kind: "open",
  surface,
  focus,
});
const close = (t: number, surface: string): Mark => ({ t, step: 0, kind: "close", surface });

const launcher: Mark[] = [open(3, "launcher", [0.34, 0.15, 0.32, 0.3]), close(6, "launcher")];

describe("cameraAt", () => {
  it("opens on the desktop as a tilted screen that settles flat and full", () => {
    const start = cameraAt(0, []);
    expect(start.scale).toBeLessThan(0.9);
    expect(Math.abs(start.tiltX) + Math.abs(start.tiltY)).toBeGreaterThan(5);
    expect(cameraAt(INTRO + 0.01, [])).toEqual(BASE);
  });

  it("frames a surface while it is open and returns to the whole desktop after", () => {
    const arrived = cameraAt(3.85, launcher);
    expect(arrived.scale).toBeGreaterThan(1.9);
    expect(arrived.x).toBeCloseTo(0.5, 1);
    expect(cameraAt(7.5, launcher)).toEqual(BASE);
  });

  it("keeps moving while a surface is held, slowly (a Ken Burns drift)", () => {
    const a = cameraAt(4, launcher);
    const b = cameraAt(5.5, launcher);
    const moved = Math.abs(a.scale - b.scale) + Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
    expect(moved).toBeGreaterThan(0.01);
    expect(moved).toBeLessThan(0.25);
  });

  it("travels from one surface to the next without pulling back when they follow closely", () => {
    const marks: Mark[] = [
      open(3, "audio", [0.81, 0.02, 0.15, 0.56]),
      close(5, "audio"),
      open(5.6, "bell", [0.85, 0.02, 0.15, 0.4]),
      close(8, "bell"),
    ];
    for (let t = 4; t <= 6.4; t += 1 / 60) expect(cameraAt(t, marks).scale).toBeGreaterThan(1.4);
  });

  it("varies how the camera arrives: not every entry is the same move", () => {
    const shots = [0, 1, 2].map((i) => [open(3 + i * 6, `s${i}`, [0.3, 0.3, 0.3, 0.3]), close(5 + i * 6, `s${i}`)]);
    const marks = shots.flat();
    const midEntry = (i: number) => cameraAt(3 + i * 6 + 0.4, marks);
    const signature = (i: number) => {
      const c = midEntry(i);
      return [Math.round(c.tiltX), Math.round(c.tiltY), Math.round(c.y * 100)].join(",");
    };
    expect(new Set([0, 1, 2].map(signature)).size).toBeGreaterThan(1);
  });

  it("reveals new windows with a breath: in a little, then back out", () => {
    const marks: Mark[] = [{ t: 4, step: 0, kind: "window" }];
    expect(cameraAt(4.5, marks).scale).toBeGreaterThan(1.1);
    expect(cameraAt(7, marks)).toEqual(BASE);
  });

  it("gives windows opening in a run one breath, not one each", () => {
    const run: Mark[] = [4, 5, 6, 7].map((t) => ({ t, step: 0, kind: "window" }) as Mark);
    // one breath: in once, then back out after the last window, no dip back to 1 in between
    for (let t = 4.6; t <= 7.5; t += 1 / 60) expect(cameraAt(t, run).scale).toBeGreaterThan(1.05);
    expect(cameraAt(10, run)).toEqual(BASE);
  });

  it("closes on the screen tilting away when the take's length is known", () => {
    const end = cameraAt(30, [], 30);
    expect(end.scale).toBeLessThan(0.9);
    expect(cameraAt(20, [], 30)).toEqual(BASE);
  });

  it("never jumps between frames", () => {
    const marks: Mark[] = [
      ...launcher,
      open(6.5, "controls", [0.34, 0.02, 0.32, 0.53]),
      close(9, "controls"),
      { t: 11, step: 0, kind: "window" },
      { t: 14, step: 0, kind: "click", point: [0.4, 0.02] },
      open(17, "kit", [0.2, 0.2, 0.6, 0.62]),
      close(20, "kit"),
    ];
    let prev = cameraAt(0, marks, 26);
    for (let t = 1 / 60; t <= 26; t += 1 / 60) {
      const c = cameraAt(t, marks, 26);
      expect(Math.abs(c.scale - prev.scale)).toBeLessThan(0.06);
      expect(Math.abs(c.x - prev.x) + Math.abs(c.y - prev.y)).toBeLessThan(0.03);
      expect(Math.abs(c.tiltX - prev.tiltX) + Math.abs(c.tiltY - prev.tiltY)).toBeLessThan(0.8);
      prev = c;
    }
  });

  it("never shows past the edge of the desktop while zoomed in", () => {
    const marks: Mark[] = [open(3, "s", [0.9, 0.9, 0.1, 0.1]), close(6, "s"), { t: 8, step: 0, kind: "click", point: [0, 1] }];
    for (let t = 0; t < 11; t += 0.05) {
      const { scale, x, y } = cameraAt(t, marks);
      if (scale < 1) continue;
      const half = 0.5 / scale;
      expect(x - half).toBeGreaterThanOrEqual(-1e-9);
      expect(x + half).toBeLessThanOrEqual(1 + 1e-9);
      expect(y - half).toBeGreaterThanOrEqual(-1e-9);
      expect(y + half).toBeLessThanOrEqual(1 + 1e-9);
    }
  });
});
