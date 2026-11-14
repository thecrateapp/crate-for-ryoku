/**
 * The cut's virtual camera: given a take's marks (tools/director writes them), where
 * to look at time t. Positions are 0..1 fractions of the recorded output; scale 1
 * shows all of it. A surface that opens with a `focus` rectangle draws the camera in
 * to frame it while it is open; a click outside any surface gives a small punch-in.
 */

export type Mark =
  | { t: number; step: number; kind: "open"; surface: string; focus?: [number, number, number, number] }
  | { t: number; step: number; kind: "close"; surface: string }
  | { t: number; step: number; kind: "click"; point: [number, number] }
  | { t: number; step: number; kind: "notify" };

export interface Camera {
  scale: number;
  x: number;
  y: number;
}

export const MAX_SCALE = 2.2;
const MARGIN = 0.85;
const SURFACE_IN = 0.8;
const SURFACE_OUT = 0.8;
const CLICK_SCALE = 1.25;
const CLICK_IN = 0.4;
const CLICK_HOLD = 0.8;
const CLICK_OUT = 0.5;

interface Shot {
  start: number;
  end: number;
  rampIn: number;
  rampOut: number;
  target: Camera;
  priority: number;
}

// Sine in-out, like the Beam: a gentle start and landing, at most pi/2 times the mean speed.
const easeInOutSine = (u: number) => (1 - Math.cos(Math.PI * u)) / 2;

const clampCentre = (value: number, scale: number) => {
  const half = 0.5 / scale;
  return Math.min(1 - half, Math.max(half, value));
};

function shots(marks: Mark[]): Shot[] {
  const out: Shot[] = [];
  marks.forEach((mark, i) => {
    if (mark.kind === "open" && mark.focus) {
      const [fx, fy, fw, fh] = mark.focus;
      const close = marks.slice(i + 1).find((m) => m.kind === "close" && m.surface === mark.surface);
      const scale = Math.min(MAX_SCALE, Math.max(1, Math.min(MARGIN / fw, MARGIN / fh)));
      out.push({
        start: mark.t,
        end: close ? close.t : Number.POSITIVE_INFINITY,
        rampIn: SURFACE_IN,
        rampOut: SURFACE_OUT,
        target: { scale, x: clampCentre(fx + fw / 2, scale), y: clampCentre(fy + fh / 2, scale) },
        priority: 1,
      });
    } else if (mark.kind === "click") {
      const [px, py] = mark.point;
      out.push({
        start: mark.t,
        end: mark.t + CLICK_IN + CLICK_HOLD,
        rampIn: CLICK_IN,
        rampOut: CLICK_OUT,
        target: { scale: CLICK_SCALE, x: clampCentre(px, CLICK_SCALE), y: clampCentre(py, CLICK_SCALE) },
        priority: 0,
      });
    }
  });
  return out;
}

function weight(shot: Shot, t: number): number {
  if (t <= shot.start) return 0;
  if (t < shot.start + shot.rampIn) return easeInOutSine((t - shot.start) / shot.rampIn);
  if (t <= shot.end) return 1;
  if (t < shot.end + shot.rampOut) return 1 - easeInOutSine((t - shot.end) / shot.rampOut);
  return 0;
}

export function cameraAt(t: number, marks: Mark[]): Camera {
  let best: { shot: Shot; w: number } | undefined;
  for (const shot of shots(marks)) {
    const w = weight(shot, t);
    if (w <= 0) continue;
    if (
      !best ||
      shot.priority > best.shot.priority ||
      (shot.priority === best.shot.priority && shot.start > best.shot.start)
    ) {
      best = { shot, w };
    }
  }
  if (!best) return { scale: 1, x: 0.5, y: 0.5 };
  const { target } = best.shot;
  const scale = 1 + (target.scale - 1) * best.w;
  return {
    scale,
    x: clampCentre(0.5 + (target.x - 0.5) * best.w, scale),
    y: clampCentre(0.5 + (target.y - 0.5) * best.w, scale),
  };
}
