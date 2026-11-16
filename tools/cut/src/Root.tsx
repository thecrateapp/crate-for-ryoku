import { Composition, staticFile, type CalculateMetadataFunction } from "remotion";
import { Cut, type CutProps, type Marks } from "./Cut";

const FPS = 60;

/** Both cuts load the take's marks; `suffix` names the vertical render apart. */
const loadMarks =
  (suffix = ""): CalculateMetadataFunction<CutProps> =>
  async ({ props, abortSignal }) => {
    const response = await fetch(staticFile(`takes/${props.take}.marks.json`), { signal: abortSignal });
    if (!response.ok) throw new Error(`no marks for take ${props.take}: run the director with --record and --output`);
    const marks = (await response.json()) as Marks;
    return {
      durationInFrames: Math.max(1, Math.ceil(marks.duration * FPS)),
      props: { ...props, marks },
      defaultOutName: `${props.take}${suffix}.mp4`,
    };
  };

export const Root = () => (
  <>
    <Composition
      id="Cut"
      component={Cut}
      fps={FPS}
      width={1920}
      height={1200}
      durationInFrames={FPS}
      defaultProps={{ take: "sample" } satisfies CutProps}
      calculateMetadata={loadMarks()}
    />
    {/* The same cut, 9:16 for phones: framing covers the height, captions sit centred at the bottom. */}
    <Composition
      id="CutVertical"
      component={Cut}
      fps={FPS}
      width={1080}
      height={1920}
      durationInFrames={FPS}
      defaultProps={{ take: "sample" } satisfies CutProps}
      calculateMetadata={loadMarks("-vertical")}
    />
  </>
);
