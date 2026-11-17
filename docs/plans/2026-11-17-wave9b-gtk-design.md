# Wave 9b: GTK apps in Crate's look — design

Date: 2026-11-17. Status: approved in conversation, pending review of this document.
Part of Wave 9 (see `2026-11-17-wave9a-editor-terminal-design.md`); Qt is out of scope (Diego uses
no Qt app; qt6ct already takes matugen's colours).

## Goal

Nautilus, Text Editor and Loupe read as Crate: Crate's code colours in Text Editor, 6 px corners
and hairlines in libadwaita, and no surface lighter than Crate's ladder.

Success: after `crate-for-ryoku install` on a Ryoku with the hook below, a capture review of
Nautilus, Text Editor (Markdown and Python) and Loupe finds nothing off; uninstall puts back
what was there; `status` says what is on.

## Found (2026-11-17)

- Colours already follow Crate: Ryoku's matugen templates render `~/.config/gtk-{3,4}.0/gtk.css`
  (libadwaita CSS variables and `@define-color`) from the palette: cyan accent, canvas window,
  object/raised sidebars and cards, popover `#111218`.
- Off: `--dialog-bg-color` and `--thumbnail-bg-color` `#282930` (lighter than any Crate surface),
  `--headerbar-border-color` a solid `#2a2b31`, Loupe's letterbox grey, and libadwaita's 9-12 px
  corners against Crate's 6 px.
- Text Editor's code colours come from GtkSourceView's Adwaita scheme (red, blue, orange, purple
  in Markdown). `gsettings org.gnome.TextEditor style-scheme` is `'Adwaita'`, `style-variant`
  `'follow'`.
- matugen rewrites `gtk.css` whole on every palette render, and Ryoku has no include for it, so a
  stylesheet of ours there would not survive.

## Decisions (Diego, 2026-11-17)

- A small generic hook in the Ryoku fork, in Ryoku's own "user include last" pattern (kitty's
  `user.conf`, Hyprland's `user.lua`): the GTK templates end with `@import url("user.css");`.
- crate-for-ryoku adds the Crate CSS and a Crate GtkSourceView scheme through `package/apps.sh`.
- Qt stays out.

## Components

### Ryoku fork: the GTK user include

- `ryoku/shell/matugen/templates/gtk4-colors.css` and `gtk3-colors.css` end with a comment and
  `@import url("user.css");` (GTK resolves it next to `gtk.css`).
- `matugenRenderTemplates` (`ryoku/shell/ipc/matugen.go`), after the app suite renders, creates an
  empty `~/.config/gtk-4.0/user.css` and `~/.config/gtk-3.0/user.css` when missing and never
  writes an existing one (GTK reports a parse error for a missing import). `blankGtk` (app theming
  off) is unchanged: no import.
- `[ryoku] shell:` commit with a CHANGELOG entry; the shipped templates reach
  `~/.config/matugen/templates` through `ryoku materialize` on the package update.

### `apps/gtk/crate.css`

Token values only (`apps/tokens.json`); rules libadwaita and adw-gtk3 honour from a user sheet:
- `:root` overrides: `--dialog-bg-color` and `--thumbnail-bg-color` popover `#111218`,
  `--headerbar-border-color` and `--scrollbar-outline-color` hairline `rgba(241,245,249,0.1)`;
  `@define-color` twins for GTK 3 / non-libadwaita.
- 6 px corners: popover contents, menus, buttons, entries, cards, dialogs and OSD button groups.
- Hairline separators and card outlines.
- Loupe's letterbox stays libadwaita's `#222226`: Loupe paints it from code, not CSS (found live).

### `apps/gtksourceview/crate.xml`

GtkSourceView 5 style scheme `id="crate"`, `name="Crate"`, metadata `variant` `dark`, the sober
syntax of Zed and Neovim: `text` `#f1f5f9` on canvas; current line raised; line numbers faint;
`def:keyword`, `def:statement`, `def:function`, `def:builtin`, `def:preprocessor` accent;
`def:string`, `def:type`, `def:heading`, `def:link-text` accent_hi; `def:number`, `def:boolean`,
`def:constant`, `def:special-char` warning; `def:comment`, `def:doc-comment` faint italic;
`def:link-destination` text secondary; `diff:removed-line` danger, `diff:added-line` accent_hi;
selection accent at low alpha; search match amber at low alpha.

### `package/apps.sh`

- GTK: copy `crate.css` to `$CFG/gtk-4.0/` and `$CFG/gtk-3.0/` (sha recorded); in each
  `user.css` add the line `@import url("crate.css"); /* crate-for-ryoku */` once (creating the
  file if absent; any other content is the user's and stays). Uninstall removes that line, and
  `crate.css` while unchanged; a `user.css` the install created and that is now empty goes.
  Status: `GTK  Crate CSS` / `Crate CSS, but this Ryoku does not load user.css` (gtk.css lacks
  the import) / `no`.
- Text Editor: install `crate.xml` into `~/.local/share/gtksourceview-5/styles/`; when
  `gnome-text-editor` is present, record `gsettings get org.gnome.TextEditor style-scheme` and set
  `crate` once (a later install never re-selects over a scheme picked since); uninstall sets the
  recorded one back while the current is still `crate`, and removes the file while unchanged.
  Status: `Text Editor  Crate scheme selected` / `installed; Crate not selected` / `not installed`.
- Flags `--no-gtk` and `--no-gtksourceview`, passed through `install.sh`.

## Error handling

Each piece warns and the run continues; nothing runs as root. GTK apps read `gtk.css` (and so
`user.css`) at start; Text Editor follows the gsettings key live.

## Testing

- Ryoku fork (Go): the templates end with the import; the render creates a missing `user.css` and
  leaves an existing one byte for byte.
- `apps/tests` (pytest): every colour in `crate.css` and `crate.xml` is a token or a token over
  canvas; `crate.xml` parses and declares `id="crate"` and the dark variant; apps.sh install,
  uninstall and status against a fake HOME with a stub `gsettings` that keeps its state in a file,
  covering a `user.css` of the user's own, a second install, a scheme picked since, edited files
  and the two flags.
- Live: fork packages with the hook built and installed, then captures of Nautilus, Text Editor
  (Markdown, Python) and Loupe reviewed with Diego.
