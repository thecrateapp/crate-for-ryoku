# App themes: Obsidian, Firefox, Chrome, Zed and lazygit

Crate's look outside the desktop shell, from the same tokens (`apps/tokens.json`):
the `#0a0a0f` canvas, `#f1f5f9` text at 62 % and 42 % for secondary and faint,
`rgba(241,245,249,0.1)` hairlines, cyan `#06b6d4` for fills and `#67e8f9` for
strokes and key words, amber `#fbbf24` and red `#ef4444` only for status, 6 px
corners, Bricolage Grotesque titles, JetBrains Mono caps labels (0.12em) and
Roboto for the rest.

`python3 apps/build.py OUT` builds them all; `python3 -m pytest apps/tests`
checks them and their installer (`package/apps.sh`) in a throwaway home, and
`bash apps/tests/package-apps.sh` checks the Chrome theme's packaging with a
throwaway key.

## What each app gets

`crate-for-ryoku install` detects each app and themes the ones it finds; an
app that is not installed is skipped with one line at most, never an error.

| App | Detected by | Piece | How it lands | Opt out |
| --- | --- | --- | --- | --- |
| Obsidian | the vaults in `~/.config/obsidian/obsidian.json` | `apps/obsidian/` theme (fonts inlined, about 200 KB) | copied into each vault (`<vault>/.obsidian/themes/Crate`) and selected: `"cssTheme": "Crate"` in `<vault>/.obsidian/appearance.json`, created if missing, every other key kept | `--no-obsidian` |
| Firefox | `profiles.ini` (`~/.mozilla/firefox`, `~/.config/mozilla/firefox`): the profile each install starts with | `apps/firefox/chrome/` `userChrome.css` + `userContent.css` + fonts | the profile's `chrome/` (WhiteSur, say) is moved to `chrome.before-crate`, ours goes in its place; `user.js` gets `toolkit.legacyUserProfileCustomizations.stylesheets` if it lacks it | `--no-firefox` |
| Firefox | | `apps/firefox/theme/` static theme add-on | addons.mozilla.org (listed); `install --firefox-theme` opens it in Firefox, which asks | opt-in |
| Chrome | `google-chrome-stable`, `google-chrome` or `chromium` on PATH | `apps/chrome/theme/` theme extension with a fixed key | the `crate-for-ryoku` package, for every user (below), and the Chrome Web Store | Chrome asks each user once |
| Zed | `zed` on PATH, `~/.local/zed.app` or `~/.config/zed` | `apps/zed/crate.json` dark theme (schema v0.2.0; terminal = the Crate kitty palette) | copied to `~/.config/zed/themes/crate.json`; `package/zed_settings.py` sets `"dark": "Crate"` in `settings.json` (or `"theme"`, when it is a single name), keeping every comment and line; a missing `settings.json` is created | `--no-zed` |
| lazygit | `lazygit` on PATH | `apps/lazygit/config.yml` (`gui.theme` only, first line `# crate-for-ryoku: lazygit`) | written to `~/.config/lazygit/config.yml` only when there is none, it is empty, or it is ours | `--no-lazygit` |

Obsidian reads `appearance.json` when a vault opens: a vault that is open
during the install shows Crate once it is reopened (or Obsidian restarted).
Firefox reads `userChrome.css` only at start: restart it. `--firefox-chrome`,
the opt-in flag before 0.7, is still accepted and does nothing more.

`crate-for-ryoku status` shows one line per app: installed or not, and where
Crate is applied (vaults with the theme and with it selected, Firefox profiles
with Crate's `userChrome.css`, Chrome profiles whose theme is Crate's and
whether the package's files are there).

`crate-for-ryoku uninstall`:

- Obsidian: each vault gets back exactly the `cssTheme` it had before (or none,
  and an `appearance.json` the install created is removed), but only while
  `cssTheme` is still `Crate`: a theme you picked since stays. A later install
  does not take that pick back either. The theme copies go only while they are
  exactly as installed; an edited copy, or a Crate theme the community store
  put there, is left alone.
- Firefox: the old `chrome/` (folder or symlink) comes back, and the pref line
  goes if the install added it. A `chrome/` you edited is kept as
  `chrome.crate-edited-<date>`.
- Zed: the dark theme `settings.json` had comes back (or the key, or the whole
  file, goes again if the install added it), while it is still `Crate`; the
  theme file goes while it is exactly as installed.
- lazygit: our `config.yml` goes (an empty one is left empty, as it was). Delete
  its first line to keep it as yours.
- `--keep-files` puts both looks back (Obsidian's previous theme, Firefox's old
  `chrome/`) and keeps the Obsidian theme copies.

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
Firefox's dark style with its purple accent. With the userChrome layer (the
default) the interface also gets Roboto, 6 px corners, a cyan hairline on the selected tab
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

## What Ryoku rewrites

**Obsidian.** Ryoku's doctor (`ryoku doctor`, which also runs inside
`ryoku update` and at the end of Ryoku's installer) links
`~/.config/matugen/generated/obsidian.css` into every vault as
`snippets/ryoku.css` and enables it. The snippet styles
`body.theme-dark.theme-dark.theme-dark` and loads after the theme, so it greys
out any theme you pick (`captures/apps/obsidian-crate-with-ryoku-snippet.png`).
In the Ryoku that Crate's pacman repository ships (the thecrateapp/ryoku fork,
commit `[ryoku] doctor: leave an Obsidian vault's own theme alone`) the doctor
keeps the snippet on only while a vault uses Obsidian's default theme and turns
it off while `appearance.json` names a `cssTheme`; it never writes `cssTheme`
itself. Stock Ryoku's doctor turns it back on at every run. The install turns
`ryoku` off in each vault where it selects Crate, as the fork's doctor would,
and uninstall turns it back on where the vault goes back to the default theme.
`status` says when the snippet is on over Crate again (stock Ryoku); turn it off
in Settings > Appearance > CSS snippets. A palette change (matugen) only
re-links the snippet file (`nudgeObsidian`); it never touches
`appearance.json`, and the Crate rice turns Ryoku's Obsidian template off
(`rice/crate/rice.json`, `"obsidian": false`).

**Firefox.** Nothing in Ryoku writes a Firefox profile's `chrome/` or
`userChrome.css`. Its doctor installs an animation sheet into Zen's profiles
only (`~/.config/zen`, which the Firefox step never reads) and the
native-messaging host of Ryoku's own browser extension. That extension (Ryoku
Theme, `ryoku-theme@ryoku.arch`) recolours Firefox live from the desktop
palette when someone installs it by hand (Ryoku installs it automatically only
into Zen); it then paints over the Crate add-on's colours, and `status` says
so. A WhiteSur `chrome/` comes from WhiteSur's own installer
(`tweaks.sh -f`), not from Ryoku; running that again would overwrite Crate's
files, and uninstall then keeps them aside as edited.

**Chrome.** Ryoku's Chromium extension is not a theme, so it does not replace
Crate's.

## The Chrome key

The theme's id, `jddiejdibphncbpfehopofclalbeghbc`, comes from the public key
in `apps/chrome/theme/manifest.json`. The private key is not in this
repository: it is `~/.local/share/crate-signing-keys/crate-chrome-theme.pem`
on Diego's machine (mode 600; `.pub.b64` and `.id` beside it). Back it up
somewhere safe: without it no `.crx` can carry the same id. `*.pem` is
git-ignored.

`python3 apps/build.py OUT --chrome-key KEY` packs the theme into a CRX3
(`OUT/chrome/crate-theme-VERSION.crx`): a small writer in `build.py` zips the
theme, signs it with `openssl dgst -sha256 -sign` and checks that the key is
the manifest's, that the packed id is `jddiejdibphncbpfehopofclalbeghbc` and
that the signature verifies. No browser is needed; its output has the same
layout as Chrome's own `--pack-extension`, whose `.crx` the same reader
verifies. `apps/chrome/pack.sh [OUT]` runs it with the key above and adds the
Web Store zip, which has no `key` field because the store refuses one.

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

### Chrome in the package

A user cannot write the folders Chrome reads external extensions from, and
Chrome 157 ignores the per-user "External Extensions" folder (tried on a
throwaway profile), so the `crate-for-ryoku` package carries the theme.
`package/build.sh` runs `package/build-chrome.sh`, which packs
`dist/crate-for-ryoku-VERSION/chrome/crate-theme.crx` with the key and writes
`chrome/jddiejdibphncbpfehopofclalbeghbc.json` from
`apps/chrome/external/crx.json`. The PKGBUILD installs the folder as
`/usr/share/crate-for-ryoku/chrome/` and the json to
`/usr/share/{google-chrome,chromium}/extensions/`; each browser then offers the
theme once to every user. Removing the package removes the offer; a theme a
user already accepted stays until they reset it (Settings > Appearance > Theme
> Reset to default).

The key lives only on the machine that builds the signed repository
(`packaging/repo/publish.sh` runs makepkg with that user's `HOME`). A build
without it (CI, an AUR build) prints a warning and ships no Chrome theme; a key
that is not the manifest's fails the build. `CRATE_CHROME_KEY` points at the key
when it lives elsewhere.

Once the Web Store listing has the same id, `apps/chrome/external/webstore.json`
(an `external_update_url`) can replace the local `.crx`, and Chrome then
updates the theme from the store.

The separate `crate-for-ryoku-chrome-theme` package this replaces was never
published, so nothing provides or replaces it.
