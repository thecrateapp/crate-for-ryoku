# App themes: Obsidian, Firefox and Chrome

Crate's look outside the desktop shell, from the same tokens (`apps/tokens.json`):
the `#0a0a0f` canvas, `#f1f5f9` text at 62 % and 42 % for secondary and faint,
`rgba(241,245,249,0.1)` hairlines, cyan `#06b6d4` for fills and `#67e8f9` for
strokes and key words, amber `#fbbf24` and red `#ef4444` only for status, 6 px
corners, Bricolage Grotesque titles, JetBrains Mono caps labels (0.12em) and
Roboto for the rest.

`python3 apps/build.py OUT` builds all three; `python3 -m pytest apps/tests`
checks them and their installer (`package/apps.sh`) in a throwaway home.

## What each app gets

| App | Piece | How it lands | Who chooses it |
| --- | --- | --- | --- |
| Obsidian | `apps/obsidian/` theme (fonts inlined, about 200 KB) | `crate-for-ryoku install` copies it into every vault in `~/.config/obsidian/obsidian.json` (`<vault>/.obsidian/themes/Crate`) | you, in Settings > Appearance > Themes; `appearance.json` is never edited |
| Firefox | `apps/firefox/theme/` static theme add-on | addons.mozilla.org (listed); `install --firefox-theme` opens it in Firefox | you, in Firefox's install prompt |
| Firefox | `apps/firefox/chrome/` `userChrome.css` + `userContent.css` + fonts | `install --firefox-chrome`: the profile's `chrome/` (WhiteSur) is moved to `chrome.before-crate`, ours goes in its place | opt-in flag only |
| Chrome | `apps/chrome/theme/` theme extension with a fixed key | Chrome Web Store, and the root package `crate-for-ryoku-chrome-theme` | Chrome asks each user once |

`crate-for-ryoku status` shows one line per app. `crate-for-ryoku uninstall`
puts Firefox's old `chrome/` back (also with `--keep-files`) and removes the
Obsidian copies that are still exactly as installed; an edited copy, or a Crate
theme the community store put there, is left alone.

## Fidelity

**Obsidian: close to Crate.** Every colour, both font roles and the radii are
Obsidian variables, so plugins and snippets follow. Bricolage 800/700 for the
inline title and h1 to h3, Roboto 600 for h4 and h5, h6 as a mono caps label;
property names, table headers, the status bar and settings section titles are
JetBrains Mono caps; callouts, code blocks, settings groups and tags are
hairlines rather than filled boxes; the active file and the focused tab carry a
cyan mark. Light mode keeps Obsidian's light colours with Crate's type, corners
and a darker cyan (`hsl(192 91% 36%)`). Captures: `captures/apps/obsidian-*`.

**Firefox: colours everywhere, shape and type only with userChrome.css.** The
add-on can set colours only: frame, toolbars, tabs, address bar, popups,
sidebar and the new tab page; Firefox's own pages (settings, add-ons) keep
Firefox's dark style with its purple accent. With `--firefox-chrome` the
interface also gets Roboto, 6 px corners, a cyan hairline on the selected tab
and the focused address bar, mono caps section labels, and the about: pages in
Crate's colours, Bricolage titles and hairline buttons. The add-on and the
userChrome layer work alone or together. Firefox reads userChrome.css only at
start: restart it after installing.

**Chrome: colours only.** A Chrome theme sets frame, toolbar, tab text,
omnibox and new tab colours. Chrome derives its accent (buttons, the profile
chip) from its own palette, keeps its own fonts and corners, and draws the
omnibox a step lighter than the colour the theme asks for. In GTK mode Chrome
ignores the theme; under the Crate rice GTK mode already comes out close
(`captures/apps/chrome-gtk-mode-no-theme.png`), but it follows whichever
palette Ryoku has, where the theme stays Crate. Picking GTK or Classic in
Settings > Appearance removes the theme; installing it again switches them off.

## Ryoku's Obsidian snippet

Ryoku's doctor links `~/.config/matugen/generated/obsidian.css` into every
vault as `snippets/ryoku.css` and enables it. The snippet styles
`body.theme-dark.theme-dark.theme-dark` and loads after the theme, so it greys
out any theme you pick (`captures/apps/obsidian-crate-with-ryoku-snippet.png`).
The fix is in the Ryoku fork, branch `fix/obsidian-snippet-theme`: the doctor
keeps the snippet on only while a vault uses Obsidian's default theme and turns
it off while `appearance.json` names a `cssTheme`. Until that ships, turn the
`ryoku` snippet off by hand in Settings > Appearance > CSS snippets; the doctor
turns it back on at its next run.

## The Chrome key

The theme's id, `jddiejdibphncbpfehopofclalbeghbc`, comes from the public key
in `apps/chrome/theme/manifest.json`. The private key is not in this
repository: it is `~/.local/share/crate-signing-keys/crate-chrome-theme.pem`
on Diego's machine (mode 600; `.pub.b64` and `.id` beside it). Back it up
somewhere safe: without it no `.crx` can carry the same id. `*.pem` is
git-ignored.

`apps/chrome/pack.sh [OUT]` packs `crate-theme-VERSION.crx` with that key
(checking it matches the manifest) and the Web Store zip, which has no `key`
field because the store refuses one.

## Publishing

### Obsidian community directory

1. Create the public repository `thecrateapp/obsidian-crate`.
2. `apps/obsidian/export.sh ~/Code/Ninja/obsidian-crate` lays it out:
   `manifest.json` and `theme.css` at the root, README, LICENSE (MIT plus the
   fonts' OFL), `screenshot.png` (512x288), `preview.png` and the release
   workflow.
3. Commit, push, then `git tag -a 1.0.0 -m 1.0.0 && git push origin 1.0.0`.
   The workflow drafts a release with `manifest.json` and `theme.css`; publish
   it. The tag must equal `version` in `manifest.json`.
4. Sign in at community.obsidian.md with an Obsidian account, link the GitHub
   account that owns the repository, and add the theme. The directory reads
   `manifest.json` from the default branch. The name "Crate" was free in the
   directory on 2026-11-16 and cannot be changed after submission.
   `apps/obsidian/community/community-css-themes-entry.json` is the entry in
   the old pull-request format, kept for reference.

Later versions: bump `version` in `apps/obsidian/manifest.json`, export,
commit, tag.

### addons.mozilla.org (listed)

1. A Firefox account, signed in on addons.mozilla.org, accepting the developer
   agreement; then an API key at addons.mozilla.org/developers/addon/api/key/.
2. Check: `npx web-ext lint --source-dir apps/firefox/theme` (0 errors, 0
   warnings on 2026-11-16).
3. Submit:

   ```sh
   export WEB_EXT_API_KEY='user:...' WEB_EXT_API_SECRET='...'
   npx web-ext sign --channel=listed --source-dir apps/firefox/theme \
     --amo-metadata apps/firefox/amo-metadata.json --artifacts-dir dist/amo
   ```

   A listed submission waits for review; once approved, AMO's page offers it
   (`https://addons.mozilla.org/firefox/addon/crate-theme/` if the slug is
   free; set the slug on the listing). The signed file from the developer hub
   goes in `apps/firefox/signed/` so the package ships it and
   `install --firefox-theme` opens it directly instead of the AMO page.
4. Listing: category Solid (Music fits too), licence MIT, summary and
   description in `apps/firefox/amo-metadata.json`. AMO draws the theme's
   preview itself.

### Chrome Web Store

1. A Chrome Web Store developer account (one-time registration fee) with the
   publisher name thecrateapp.
2. First upload: `apps/chrome/pack.sh`, then upload
   `crate-theme-1.0.0-webstore.zip`. The store assigns its own id. To keep
   `jddiejdibphncbpfehopofclalbeghbc`, the store has accepted a `key.pem` at
   the root of the first upload's zip (the private key, renamed); check that it
   still does before relying on it, and never commit that zip.
3. Listing: category Themes; icon `apps/chrome/store/icon128.png`; screenshots
   `apps/chrome/store/screenshot-*-1280x800.png`; small promo tile
   `apps/chrome/store/promo-small-440x280.png`. Single purpose: "A colour
   theme for Chrome in Crate's look." No permissions, no data collected.
   Description:

   > Crate's look for Chrome: the frame and tabs on Crate's near-black canvas,
   > a quiet toolbar, light text and a dark new tab page with a white logo.
   > A colour theme only: no permissions, nothing collected. From Crate for
   > Ryoku (https://github.com/thecrateapp/crate-for-ryoku).

### The Chrome package

`packaging/aur/crate-for-ryoku-chrome-theme/` installs the `.crx` to
`/usr/share/crate-for-ryoku/chrome/` and an external-extension file for Google
Chrome and Chromium (`/usr/share/{google-chrome,chromium}/extensions/ID.json`).
Each browser then offers the theme once to every user. It needs the `.crx` as a
release asset (`pack.sh`, uploaded to the crate-for-ryoku release named in
`_release`) and its checksum in `sha256sums`. Once the Web Store listing has the
same id, `ID.webstore.json` (an `external_update_url`) can replace the local
`.crx`, and Chrome then updates the theme from the store.

Chrome's per-user "External Extensions" folder was tried on a throwaway profile
and Chrome 157 ignores it, so a per-user install is not possible; the package
route was built with makepkg but not installed, as it needs root.
