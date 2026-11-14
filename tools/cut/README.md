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

The take is recorded 3840 x 2400 (16:10) on eDP-1 and cut to 1920 x 1080 (16:9) at
60 fps, so a 2x zoom keeps full detail. Takes and renders are git-ignored.

| File | What |
|---|---|
| `src/camera.ts` | where the camera looks at time t, from the marks (tested) |
| `src/framing.ts` | camera to pixels: covers 16:9, never shows an empty edge (tested) |
| `src/Cut.tsx`, `src/Root.tsx` | the composition; `calculateMetadata` loads the marks |

Camera timing: 0.8 s sine ease into and out of a surface (max 2.2x, 85 % margin);
a click outside a surface punches in to 1.25x for 1.2 s. `npm test` runs the camera
and framing tests.

Remotion is free for individuals and companies of up to three people; see
remotion.dev/license.
