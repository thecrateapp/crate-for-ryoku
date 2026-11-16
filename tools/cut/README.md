# cut

Turns a director take into the finished clip with Remotion: a virtual camera eases in
on each shell surface while it is open (its `focus` rectangle in the timeline) and
gives a small punch-in on each click, then eases back out. Everything comes from the
take's `NAME.marks.json`, so a re-recorded take re-cuts itself with no manual edit.

```sh
cd tools/cut && npm ci
# record (tools/director): the take and its marks land in public/takes/
../director/director.py ../director/timelines/hero.json --record public/takes/hero.mp4 --output eDP-1
npm run studio                                             # preview, scrub, tune
npx remotion render Cut out/hero.mp4 --props='{"take":"hero"}'
npx remotion render CutVertical out/hero-vertical.mp4 --props='{"take":"hero"}'   # 9:16
```

The take is recorded 3840 x 2400 (16:10) on eDP-1 and cut to 1920 x 1200 (16:10, so
the bar and dock are never trimmed) at 60 fps; a 2x zoom keeps full detail. Takes and renders are git-ignored.

| File | What |
|---|---|
| `src/camera.ts` | where the camera looks at time t, from the marks (tested) |
| `src/framing.ts` | camera to pixels: covers 16:9, never shows an empty edge (tested) |
| `src/captions.ts` | which caption shows at time t, with its fades (tested) |
| `src/fonts.ts` | loads the caption fonts from `public/fonts` before the first frame renders |
| `src/Cut.tsx`, `src/Root.tsx` | the compositions `Cut` (1920 x 1200) and `CutVertical` (1080 x 1920); `calculateMetadata` loads the marks |

The camera is a small shot grammar, not one move: a 3D opening and closing (the
desktop as a tilted screen over Crate's ground), arrivals that take turns (push,
swing with a 3D turn, rise), a slow Ken Burns drift while a surface is held, a
travelling move straight to the next surface when it follows within 1.6 s, and a
breath (in, then back out) when windows appear. `npm test` runs the camera
and framing tests.

Captions come from the timeline's `caption` steps (tools/director): each shows from its
mark until the next caption, fading in and out over 0.35 s, and an empty `text` clears it.
They sit above the camera (no tilt or zoom) in Crate's site type: a JetBrains Mono eyebrow
in cyan over a Bricolage Grotesque line, on a soft dark gradient; bottom-left in `Cut`,
bottom and centred in `CutVertical`.

The caption fonts in `public/fonts/` (Bricolage Grotesque, JetBrains Mono) are under the SIL
Open Font License 1.1; their licences sit next to them.

Remotion is free for individuals and companies of up to three people; see
remotion.dev/license.

## Showcase screenshots

`python3 tools/cut/shots.py OUT` composes ryoku.cratemusic.app's screenshot showcase from the
takes (one frame per surface, cropped around it, inset on the site background; wide and
portrait, each in two sizes). Upload them from the crate repo with
`make ryoku-media-sync SRC=<dir>` where `<dir>/shots/` holds the output; the site serves them
from `/media/shots/`.
