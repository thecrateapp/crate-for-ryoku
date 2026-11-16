import { Video } from "@remotion/media";
import { AbsoluteFill, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { cameraAt, type Mark } from "./camera";
import { captionAt, type Caption } from "./captions";
import { DISPLAY, loadCaptionFonts, MONO } from "./fonts";
import { framing } from "./framing";
import { redactionsAt, toPixels } from "./redact";

loadCaptionFonts();

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
      <CaptionLayer caption={captionAt(t, marks.events, marks.duration)} width={width} height={height} />
    </AbsoluteFill>
  );
};

/**
 * A caption over the cut, outside the camera and its 3D tilt, in Crate's site type: a mono
 * eyebrow over a Bricolage line on a soft dark gradient. Bottom-left in landscape; bottom
 * and centred, a little larger, in a vertical cut.
 */
const CaptionLayer = ({ caption, width, height }: { caption: Caption | null; width: number; height: number }) => {
  if (!caption) return null;
  const portrait = height > width;
  const size = portrait ? width * 0.068 : height * 0.042;
  const eyebrow = Math.round(size * (portrait ? 0.34 : 0.38));
  const rise = (1 - caption.opacity) * size * 0.3;
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <AbsoluteFill
        style={{
          opacity: caption.opacity,
          background: portrait
            ? "linear-gradient(to bottom, rgba(10, 10, 15, 0) 42%, rgba(10, 10, 15, 0.5) 62%, rgba(10, 10, 15, 0.75) 76%, rgba(10, 10, 15, 0.75) 100%)"
            : "linear-gradient(to bottom, rgba(10, 10, 15, 0) 50%, rgba(10, 10, 15, 0.5) 72%, rgba(10, 10, 15, 0.75) 84%, rgba(10, 10, 15, 0.75) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          ...(portrait
            ? {
                left: "50%",
                bottom: height * 0.1,
                width: width * 0.85,
                marginLeft: -width * 0.425,
                textAlign: "center",
              }
            : { left: width * 0.05, bottom: height * 0.075, maxWidth: width * 0.62 }),
          opacity: caption.opacity,
          transform: `translateY(${rise}px)`,
        }}
      >
        {caption.eyebrow ? (
          <div
            style={{
              fontFamily: `"${MONO}", monospace`,
              fontWeight: 400,
              fontSize: eyebrow,
              lineHeight: 1.2,
              letterSpacing: "0.12em",
              textTransform: "uppercase",
              color: "#67e8f9",
              marginBottom: size * 0.32,
            }}
          >
            {caption.eyebrow}
          </div>
        ) : null}
        <div
          style={{
            fontFamily: `"${DISPLAY}", sans-serif`,
            fontWeight: 800,
            fontSize: size,
            lineHeight: 1.06,
            letterSpacing: "-0.02em",
            color: "#f1f5f9",
            textWrap: "balance",
            textShadow: "0 2px 28px rgba(10, 10, 15, 0.6)",
          }}
        >
          {caption.text}
        </div>
      </div>
    </AbsoluteFill>
  );
};
