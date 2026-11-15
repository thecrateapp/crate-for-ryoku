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
```

The take is recorded 3840 x 2400 (16:10) on eDP-1 and cut to 1920 x 1200 (16:10, so
the bar and dock are never trimmed) at 60 fps; a 2x zoom keeps full detail. Takes and renders are git-ignored.

| File | What |
|---|---|
| `src/camera.ts` | where the camera looks at time t, from the marks (tested) |
| `src/framing.ts` | camera to pixels: covers 16:9, never shows an empty edge (tested) |
| `src/Cut.tsx`, `src/Root.tsx` | the composition; `calculateMetadata` loads the marks |

The camera is a small shot grammar, not one move: a 3D opening and closing (the
desktop as a tilted screen over Crate's ground), arrivals that take turns (push,
swing with a 3D turn, rise), a slow Ken Burns drift while a surface is held, a
travelling move straight to the next surface when it follows within 1.6 s, and a
breath (in, then back out) when windows appear. `npm test` runs the camera
and framing tests.

Remotion is free for individuals and companies of up to three people; see
remotion.dev/license.
