import { cancelRender, continueRender, delayRender, staticFile } from "remotion";

/** Crate's site type for captions (both SIL OFL; files and licences in public/fonts). */
export const DISPLAY = "Bricolage Grotesque";
export const MONO = "JetBrains Mono";

const FACES = [
  { family: DISPLAY, file: "fonts/bricolage-grotesque-latin-opsz-normal.woff2", weight: "200 800" },
  { family: MONO, file: "fonts/jetbrains-mono-latin-400-normal.woff2", weight: "400" },
];

let loading: Promise<void> | undefined;

/** Loads the caption fonts once and holds the render until they are ready. */
export function loadCaptionFonts(): void {
  if (loading || typeof document === "undefined") return;
  const handle = delayRender("Loading caption fonts");
  loading = Promise.all(
    FACES.map(async ({ family, file, weight }) => {
      const face = new FontFace(family, `url("${staticFile(file)}") format("woff2")`, { weight });
      document.fonts.add(await face.load());
    }),
  )
    .then(() => continueRender(handle))
    .catch((error) => cancelRender(error));
}
