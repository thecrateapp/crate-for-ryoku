# Draft: comment on crmne/zapfast#965 (not posted)

> Target: https://github.com/crmne/zapfast/issues/965, as a comment on its
> point 3 ("Sizes"). Post only after review. Written against ZapFast 0.21.2
> and fastframe v0.16.1.

---

I'd like to take on point 3 (sizes) and want to agree on the format before
opening anything, since it starts in `fastframe-theme`.

**Use case.** We theme a whole Linux desktop from one palette (Ryoku, a
Hyprland desktop). It renders a ZapFast palette file on every theme change,
and ZapFast's live reload picks it up, which works very well. Colours already
match the rest of the desktop. What doesn't is shape: the desktop uses 6 px
corners and flat surfaces, and a theme can't say that today.

**Proposal: an optional `style` object next to `colors`.**

```json
{
  "base": "dark",
  "colors": { "accent": "#06b6d4" },
  "style": {
    "radius": 6,
    "radius_small": 4,
    "focus_stroke": 1.0,
    "shadows": "none"
  }
}
```

- Every key is optional and defaults to today's value (`RADIUS` 8,
  `RADIUS_SMALL` 4, `FOCUS_STROKE_WIDTH` 1.0, shadows on), so every built-in
  and existing palette stays pixel-identical.
- Values are validated like colours: a radius outside 0 to 24, a stroke
  outside 0 to 4, or an unknown key makes the file invalid, with the key
  named in the error. That keeps the `deny_unknown_fields` strictness.
- `shadows` is `"soft"` (today) or `"none"`. A theme can already thin the
  float and modal shadows by giving `shadow` alpha, but the bubble shadow and
  the raised top edge are drawn regardless.
- Pills (`height / 2`) stay pills. Fonts and spacing density are left out on
  purpose: fonts belong with `fastframe-fonts` (as #335 concluded) and density
  touches far more code. Both can follow the same "optional, defaults to
  today" pattern later.

**Shape of the change.**

1. `fastframe-theme`: a `Style` type with optional fields, read by a
   `parse_style(text)` beside `parse_palette`, so the `Palette` trait and its
   implementers don't change. `PaletteFile` gains `style:
   Option<StyleFile>`. Spotifast would accept the key and could adopt it when
   it wants. Tests for defaults, bounds and unknown keys.
2. ZapFast: the resolved style is stored once per palette change, next to
   the active palette, and the ~40
   uses of `RADIUS`/`RADIUS_SMALL`, the 6 uses of `FOCUS_STROKE_WIDTH` and the
   three shadow helpers read it instead of the constants. Literal radii
   (`CornerRadius::same(6)` and similar) that mean "the theme radius" move to
   it too; ones that are geometry (avatars, pills) stay.

One compatibility note: a ZapFast build older than this rejects a file with
`style` as an unknown field and keeps its last palette, so a theme using the
key needs the new version. Writing the style to a separate file would avoid
that, but one file per theme seemed simpler. Happy to go either way.

If this direction works for you, I can open the `fastframe-theme` PR first
and the ZapFast one after it, each with light and dark before/after
screenshots as CONTRIBUTING asks.
