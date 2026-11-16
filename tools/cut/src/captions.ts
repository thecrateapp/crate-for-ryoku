import type { Mark } from "./camera";

/** Seconds a caption takes to fade in, and to fade out before the next one or a clear. */
export const CAPTION_FADE = 0.35;

export interface Caption {
  eyebrow?: string;
  text: string;
  opacity: number;
}

type CaptionMark = Extract<Mark, { kind: "caption" }>;

const smooth = (u: number) => (1 - Math.cos(Math.PI * Math.min(1, Math.max(0, u)))) / 2;

/**
 * The caption on screen at time t: the last caption mark at or before t, shown until the
 * next caption mark (or the end of the take, when `duration` is given). It fades in over
 * CAPTION_FADE and out over CAPTION_FADE before whatever replaces it; a caption with
 * empty text is a clear and shows nothing.
 */
export function captionAt(t: number, events: Mark[], duration?: number): Caption | null {
  const captions = events.filter((m): m is CaptionMark => m.kind === "caption").sort((a, b) => a.t - b.t);
  let index = -1;
  for (let i = 0; i < captions.length; i++) if (captions[i].t <= t) index = i;
  if (index < 0) return null;
  const current = captions[index];
  if (!current.text) return null;
  const end = captions[index + 1]?.t ?? duration;
  const fadeIn = smooth((t - current.t) / CAPTION_FADE);
  const fadeOut = end === undefined ? 1 : smooth((end - t) / CAPTION_FADE);
  const opacity = Math.min(fadeIn, fadeOut);
  if (opacity <= 0) return null;
  return { ...(current.eyebrow ? { eyebrow: current.eyebrow } : {}), text: current.text, opacity };
}
