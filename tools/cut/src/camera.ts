/**
 * The cut's virtual camera: where to look at time t, given a take's marks (written by
 * tools/director). Positions are 0..1 fractions of the recorded output; scale 1 shows
 * all of it, below 1 shows it as a screen floating in the frame; tilt is in degrees.
 *
 * The camera is a keyframe timeline built from a small shot grammar so it never repeats
 * one move: a 3D opening and closing, three ways of arriving on a surface (push, swing,
 * rise) in turn, a slow Ken Burns drift while a surface is held, a travelling move
 * straight to the next surface when it follows closely, and a breath (in a little, back
 * out) when new windows appear.
 */

export type Mark =
  | {
      t: number;
      step: number;
      kind: "open";
      surface: string;
      focus?: [number, number, number, number];
      /** Private data on the surface (0..1 boxes on the output) the cut blurs while it is open. */
      redact?: [number, number, number, number][];
    }
  | { t: number; step: number; kind: "close"; surface: string }
  | { t: number; step: number; kind: "click"; point: [number, number] }
  | { t: number; step: number; kind: "notify" }
  | { t: number; step: number; kind: "window" };

export interface Camera {
  scale: number;
  x: number;
  y: number;
  tiltX: number;
  tiltY: number;
}

export const BASE: Camera = { scale: 1, x: 0.5, y: 0.5, tiltX: 0, tiltY: 0 };
export const INTRO = 2.2;
export const OUTRO = 2.2;
export const MAX_SCALE = 2.2;

const INTRO_FROM: Camera = { scale: 0.8, x: 0.5, y: 0.5, tiltX: 12, tiltY: -14 };
const OUTRO_TO: Camera = { scale: 0.8, x: 0.5, y: 0.5, tiltX: 10, tiltY: 14 };
const MARGIN = 0.85;
const RAMP_IN = 0.8;
const RAMP_OUT = 0.8;
const TRAVEL_GAP = 1.6;
const CLICK_SCALE = 1.25;
const CLICK_HOLD = 1.2;
const REVEAL_IN = 0.5;
const REVEAL_OUT = 1.7;
const REVEAL_SCALE = 1.16;
const STEP = 0.02;

/** Per held shot, in turn: push in, ease back, drift left, rise. */
const DRIFTS = [
  { scale: 0.06, dx: 0.015, dy: 0 },
  { scale: -0.05, dx: 0, dy: -0.012 },
  { scale: 0.04, dx: -0.015, dy: 0 },
  { scale: 0.05, dx: 0, dy: 0.012 },
];

type Ease = "linear" | "sine" | "in" | "out";

interface Key {
  t: number;
  cam: Camera;
  ease: Ease;
}

interface Shot {
  kind: "surface" | "reveal";
  start: number;
  end: number;
  target: Camera;
  /** A reveal's last window: windows opening in a run share one breath. */
  last?: number;
}

const ease = (kind: Ease, u: number) => {
  switch (kind) {
    case "linear":
      return u;
    case "in":
      return 1 - Math.cos((Math.PI * u) / 2);
    case "out":
      return Math.sin((Math.PI * u) / 2);
    default:
      return (1 - Math.cos(Math.PI * u)) / 2;
  }
};

/** Keeps a zoomed view inside the desktop; below full size the screen stays centred. */
const clampCentre = (value: number, scale: number) => {
  if (scale <= 1) return 0.5;
  const half = 0.5 / scale;
  return Math.min(1 - half, Math.max(half, value));
};

const mix = (a: Camera, b: Camera, u: number): Camera => ({
  scale: a.scale + (b.scale - a.scale) * u,
  x: a.x + (b.x - a.x) * u,
  y: a.y + (b.y - a.y) * u,
  tiltX: a.tiltX + (b.tiltX - a.tiltX) * u,
  tiltY: a.tiltY + (b.tiltY - a.tiltY) * u,
});

const framed = (scale: number, x: number, y: number): Camera => ({
  scale,
  x: clampCentre(x, scale),
  y: clampCentre(y, scale),
  tiltX: 0,
  tiltY: 0,
});

function shotsOf(marks: Mark[]): Shot[] {
  const shots: Shot[] = [];
  marks.forEach((mark, i) => {
    if (mark.kind === "open" && mark.focus) {
      const [fx, fy, fw, fh] = mark.focus;
      const closeMark = marks.slice(i + 1).find((m) => m.kind === "close" && m.surface === mark.surface);
      const scale = Math.min(MAX_SCALE, Math.max(1, Math.min(MARGIN / fw, MARGIN / fh)));
      shots.push({
        kind: "surface",
        start: mark.t,
        end: closeMark ? closeMark.t : mark.t + 4,
        target: framed(scale, fx + fw / 2, fy + fh / 2),
      });
    } else if (mark.kind === "click") {
      shots.push({
        kind: "surface",
        start: mark.t,
        end: mark.t + CLICK_HOLD,
        target: framed(CLICK_SCALE, mark.point[0], mark.point[1]),
      });
    } else if (mark.kind === "window" || (mark.kind === "open" && !mark.focus)) {
      const run = shots.find((s) => s.kind === "reveal" && mark.t - (s.last ?? s.start) <= REVEAL_IN + REVEAL_OUT);
      if (run) {
        run.last = mark.t;
        run.end = mark.t + REVEAL_IN + REVEAL_OUT;
      } else {
        shots.push({ kind: "reveal", start: mark.t, last: mark.t, end: mark.t + REVEAL_IN + REVEAL_OUT, target: BASE });
      }
    }
  });
  return shots.sort((a, b) => a.start - b.start);
}

function drifted(target: Camera, index: number): Camera {
  const d = DRIFTS[index % DRIFTS.length];
  const scale = Math.min(MAX_SCALE * 1.06, Math.max(1, target.scale * (1 + d.scale)));
  return framed(scale, target.x + d.dx, target.y + d.dy);
}

/** The midpoint of an arrival: push (straight), swing (a 3D turn) or rise (from below). */
function entryMid(from: Camera, to: Camera, index: number): Camera {
  const mid = mix(from, to, 0.5);
  switch (index % 3) {
    case 1: {
      const side = Math.floor(index / 3) % 2 === 0 ? 1 : -1;
      return { ...mid, tiltX: 2, tiltY: 7 * side };
    }
    case 2:
      return { ...mid, y: mid.y + 0.05, tiltX: -3 };
    default:
      return mid;
  }
}

function keyframes(marks: Mark[], duration?: number): Key[] {
  const keys: Key[] = [
    { t: 0, cam: INTRO_FROM, ease: "linear" },
    { t: INTRO, cam: BASE, ease: "sine" },
  ];
  const add = (t: number, cam: Camera, kind: Ease) => {
    const last = keys[keys.length - 1];
    keys.push({ t: Math.max(t, last.t + STEP), cam, ease: kind });
  };

  let held: { end: number } | undefined; // a surface still framed, not yet pulled back from
  let index = 0;
  const pullBack = () => {
    if (!held) return;
    add(held.end + RAMP_OUT, BASE, "sine");
    held = undefined;
  };

  for (const shot of shotsOf(marks)) {
    if (shot.kind === "reveal") {
      if (held && shot.start < held.end + RAMP_OUT) continue; // a surface owns the frame
      pullBack();
      const last = shot.last ?? shot.start;
      add(shot.start, BASE, "linear");
      add(shot.start + REVEAL_IN, { ...BASE, scale: REVEAL_SCALE, tiltX: 2 }, "sine");
      if (last > shot.start) add(last + REVEAL_IN, { ...BASE, scale: REVEAL_SCALE * 1.03, tiltX: 1 }, "linear");
      add(last + REVEAL_IN + REVEAL_OUT, BASE, "sine");
      continue;
    }
    const arrive = shot.start + RAMP_IN;
    const travel = held !== undefined && shot.start - held.end <= TRAVEL_GAP;
    if (travel) {
      add(arrive, shot.target, "sine");
    } else {
      pullBack();
      add(shot.start, BASE, "linear");
      add(shot.start + RAMP_IN / 2, entryMid(BASE, shot.target, index), "in");
      add(arrive, shot.target, "out");
    }
    const holdEnd = Math.max(arrive + STEP, shot.end);
    add(holdEnd, drifted(shot.target, index), "linear");
    held = { end: holdEnd };
    index += 1;
  }
  pullBack();

  if (duration !== undefined && duration > INTRO + OUTRO) {
    add(duration - OUTRO, BASE, "linear");
    add(duration, OUTRO_TO, "sine");
  }
  return keys;
}

export function cameraAt(t: number, marks: Mark[], duration?: number): Camera {
  const keys = keyframes(marks, duration);
  let cam = keys[keys.length - 1].cam;
  for (let k = 1; k < keys.length; k++) {
    if (t < keys[k].t) {
      const a = keys[k - 1];
      const b = keys[k];
      const u = Math.min(1, Math.max(0, (t - a.t) / (b.t - a.t)));
      cam = mix(a.cam, b.cam, ease(b.ease, u));
      break;
    }
  }
  return { ...cam, x: clampCentre(cam.x, cam.scale), y: clampCentre(cam.y, cam.scale) };
}
