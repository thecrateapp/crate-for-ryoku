import { Video } from "@remotion/media";
import { AbsoluteFill, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { cameraAt, type Mark } from "./camera";
import { framing } from "./framing";
import { redactionsAt, toPixels } from "./redact";

export type Marks = {
  take: string;
  duration: number;
  output: { name: string; width: number; height: number; scale: number; x: number; y: number };
  events: Mark[];
};

export type CutProps = {
  /** Take name in public/takes: `hero` reads hero.mp4 and hero.marks.json. */
  take: string;
  marks?: Marks;
};

export const Cut = ({ take, marks }: CutProps) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  if (!marks) return <AbsoluteFill style={{ background: "#0a0a0f" }} />;
  const t = frame / fps;
  const camera = cameraAt(t, marks.events, marks.duration);
  const box = framing(camera, marks.output, { width, height });
  // Below full size the desktop is a screen floating over Crate's ground.
  const floating = Math.min(1, Math.max(0, (1 - camera.scale) / 0.2));
  return (
    <AbsoluteFill
      style={{
        background: "radial-gradient(ellipse 80% 70% at 50% 45%, rgba(6, 182, 212, 0.10), #0a0a0f 70%)",
        overflow: "hidden",
      }}
    >
      <AbsoluteFill
        style={{
          transform: `perspective(2600px) rotateX(${camera.tiltX}deg) rotateY(${camera.tiltY}deg)`,
          transformOrigin: "50% 50%",
        }}
      >
        <Video
          src={staticFile(`takes/${take}.mp4`)}
          style={{
            position: "absolute",
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
            borderRadius: 14 * floating,
            boxShadow: `0 ${40 * floating}px ${120 * floating}px rgba(0, 0, 0, ${0.6 * floating}), 0 0 0 1px rgba(241, 245, 249, ${0.08 * floating})`,
          }}
        />
        {redactionsAt(t, marks.events).map((b, i) => {
          const r = toPixels(b, box);
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: r.left,
                top: r.top,
                width: r.width,
                height: r.height,
                borderRadius: 6,
                backdropFilter: "blur(14px) saturate(0.6)",
                background: "rgba(10, 10, 15, 0.25)",
              }}
            />
          );
        })}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
