import { Video } from "@remotion/media";
import { AbsoluteFill, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { cameraAt, type Mark } from "./camera";
import { framing } from "./framing";

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
  const camera = cameraAt(frame / fps, marks.events);
  const box = framing(camera, marks.output, { width, height });
  return (
    <AbsoluteFill style={{ background: "#0a0a0f", overflow: "hidden" }}>
      <Video
        src={staticFile(`takes/${take}.mp4`)}
        style={{ position: "absolute", left: box.left, top: box.top, width: box.width, height: box.height }}
      />
    </AbsoluteFill>
  );
};
