import { Composition, staticFile, type CalculateMetadataFunction } from "remotion";
import { Cut, type CutProps, type Marks } from "./Cut";

const FPS = 60;

const loadMarks: CalculateMetadataFunction<CutProps> = async ({ props, abortSignal }) => {
  const response = await fetch(staticFile(`takes/${props.take}.marks.json`), { signal: abortSignal });
  if (!response.ok) throw new Error(`no marks for take ${props.take}: run the director with --record and --output`);
  const marks = (await response.json()) as Marks;
  return {
    durationInFrames: Math.max(1, Math.ceil(marks.duration * FPS)),
    props: { ...props, marks },
    defaultOutName: `${props.take}.mp4`,
  };
};

export const Root = () => (
  <Composition
    id="Cut"
    component={Cut}
    fps={FPS}
    width={1920}
    height={1080}
    durationInFrames={FPS}
    defaultProps={{ take: "sample" } satisfies CutProps}
    calculateMetadata={loadMarks}
  />
);
