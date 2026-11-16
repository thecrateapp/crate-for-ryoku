import { describe, expect, it } from "vitest";
import type { Mark } from "./camera";
import { CAPTION_FADE, captionAt } from "./captions";

const caption = (t: number, text: string, eyebrow?: string): Mark => ({
  t,
  step: 0,
  kind: "caption",
  text,
  ...(eyebrow ? { eyebrow } : {}),
});

const marks: Mark[] = [
  { t: 1, step: 0, kind: "window" },
  caption(2, "One glass, every surface", "Crate for Ryoku"),
  caption(6, "Plain text"),
  caption(9, ""),
];

describe("captionAt", () => {
  it("shows nothing before the first caption or with no captions at all", () => {
    expect(captionAt(1.9, marks)).toBeNull();
    expect(captionAt(5, [{ t: 1, step: 0, kind: "notify" }])).toBeNull();
  });

  it("holds a caption at full opacity between its fades, with its eyebrow", () => {
    expect(captionAt(4, marks)).toEqual({ eyebrow: "Crate for Ryoku", text: "One glass, every surface", opacity: 1 });
    expect(captionAt(7, marks)).toEqual({ text: "Plain text", opacity: 1 });
  });

  it("fades in over 0.35 s from its mark", () => {
    expect(captionAt(2, marks)).toBeNull();
    const mid = captionAt(2 + CAPTION_FADE / 2, marks)!;
    expect(mid.opacity).toBeCloseTo(0.5);
    expect(captionAt(2 + CAPTION_FADE, marks)!.opacity).toBeCloseTo(1);
    let prev = 0;
    for (let t = 2.01; t <= 2 + CAPTION_FADE; t += 0.01) {
      const o = captionAt(t, marks)!.opacity;
      expect(o).toBeGreaterThanOrEqual(prev);
      prev = o;
    }
  });

  it("fades out over 0.35 s before the next caption replaces it", () => {
    expect(captionAt(6 - CAPTION_FADE, marks)!.opacity).toBeCloseTo(1);
    expect(captionAt(6 - CAPTION_FADE / 2, marks)!.opacity).toBeCloseTo(0.5);
    expect(captionAt(6 - CAPTION_FADE / 2, marks)!.text).toBe("One glass, every surface");
    expect(captionAt(6, marks)).toBeNull();
    expect(captionAt(6 + CAPTION_FADE / 2, marks)!.text).toBe("Plain text");
  });

  it("fades out before a clear, and a clear hides it", () => {
    expect(captionAt(9 - CAPTION_FADE / 2, marks)!.opacity).toBeCloseTo(0.5);
    expect(captionAt(9, marks)).toBeNull();
    expect(captionAt(20, marks)).toBeNull();
  });

  it("stays until the end of the take, fading out before it when the length is known", () => {
    const open: Mark[] = [caption(2, "Last word")];
    expect(captionAt(100, open)!.opacity).toBe(1);
    expect(captionAt(10 - CAPTION_FADE / 2, open, 10)!.opacity).toBeCloseTo(0.5);
    expect(captionAt(10, open, 10)).toBeNull();
  });

  it("reads captions in time order even if the marks are not", () => {
    const shuffled: Mark[] = [caption(6, "second"), caption(2, "first")];
    expect(captionAt(4, shuffled)!.text).toBe("first");
    expect(captionAt(7, shuffled)!.text).toBe("second");
  });
});
