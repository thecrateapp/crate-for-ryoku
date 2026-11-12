# Crate desktop on Ryoku / Hyprland: what to change

State of `app/listen-desktop` on `feat/crate_mcp` (Tauri 2, WebKitGTK), checked against what Ryoku
1.0.7 offers an app. Paths are relative to the Crate repo root. Tested so far only on GNOME Wayland
(`docs/testing/tauri-linux-desktop-results-2026-09-30.md`); Hyprland is not mentioned anywhere.

Split: **A** is changes to the Crate app, **B** is what Crate for Ryoku can do with no app change.

**Status (2026-11-11), branch `feat/linux_desktop_ryoku`** (worktree
`crate-agents/linux-desktop`, from main d239e0395, not committed):
- Done: A1 (minimum 600x480 on tiling compositors), A2 (no clamp on tiling), A3 (app_id
  = `app.cratemusic.crate.desktop` via the GLib program name), A4 (MPRIS seek, volume,
  shuffle, loop), A5 (logind sleep inhibitor while playing), A6 (no titlebar on tiling),
  A8 (control socket, protocol 1, with EQ). Tests: 72 Rust, desktop vitest, Listen
  vitest green. Checked in the nested sandbox and live.
- Rice side done: crate-mark 0.4.0 (panel like the bar's volume panel, Crate EQ over the
  socket, shown only while Crate is installed).
- Also done: A7 track notifications, A9 launcher provider (`cr <query>` via
  `crate-desktop --launcher`, registered by the rice), A12 local MCP
  (`crate-desktop --mcp`: now playing, transport, EQ, search and play), P2 AUR package
  (`packaging/aur/crate-desktop-bin`, builds with makepkg, not published).
- Not done: A10 live theme (out of scope: the Crate V3 identity is fixed), A11 tray icon.
- Open in Crate itself: the player volume is the webview's gain, not the system volume.
  Either sync it with the system (PipeWire stream volume) or drop Crate's own volume
  control on desktop. The Ryoku plugin has no volume slider until then.

## What already works

- **Native MPRIS** over zbus: `org.mpris.MediaPlayer2.crate`, title, artist, album and length.
  Cover art is cached to a `file://` URL, which the Ryoku media daemon can read.
  Play, pause, next, previous and raise work (`src-tauri/src/linux_media_controls.rs`).
- **Ryoku media keys:** they run a bare `playerctl` (`~/.config/hypr/modules/binds.lua:175-177`),
  so they already reach Crate over MPRIS.
- **Tray icon** through StatusNotifierItem, with a menu. Ryoku's bar draws the tray.
- **Single instance**, with the `--crate-command=play|pause|play_pause|previous|next|show|hide`
  flags (`src-tauri/src/lib.rs:201-217`).
- **`cratemusic://` scheme:** registered, but only used for OAuth so far.
- **Theme:** reads the portal's `color-scheme` and `accent-color`, plus the system font.
- **Wayland:** forced when the session is Wayland (`lib.rs:1437-1451`).

## A. Changes to the app

### P0: it misbehaves on a tiling compositor today

1. **Minimum size 1280x820** (`src-tauri/tauri.linux.conf.json`). The whole window is fixed at
   this size, so a half-screen tile on a 1920 px monitor (about 950 px wide) cannot hold it.
   - Lower the minimum to something like 400x560 and let Listen's responsive layout take over.
2. **The bounds clamp fights the compositor.** On every move or resize it calls `set_size` and
   `set_position` (`lib.rs:854-1013`, the calls at about lines 945-948).
   - On Hyprland the compositor owns the geometry of tiled windows, and Wayland ignores
     `set_position` anyway.
   - Skip the clamp when the window is tiled or when the session is not GNOME/KDE. Simplest:
     run it only when `XDG_CURRENT_DESKTOP` is GNOME or KDE.
3. **One identity.** The config asks for app_id `app.cratemusic.crate.desktop` (the Tauri
   identifier plus `enableGTKAppId`), and both desktop files declare
   `StartupWMClass=app.cratemusic.crate.desktop`. But the released 3.3.1 window reports Hyprland
   class `crate-desktop` (checked with `hyprctl clients` on 2026-11-11), so `StartupWMClass`
   matches nothing; Ryoku's dock can only fall back to the Exec basename. Here there are three
   desktop files:
   - the package's `Crate.desktop`, with `Icon=crate-desktop`;
   - the one the app writes at startup, `app.cratemusic.crate.desktop.desktop`, with `NoDisplay`
     and `Icon=app.cratemusic.crate.desktop`;
   - a local `crate-desktop-handler.desktop`.

   Ryoku's dock matches a window to its entry by desktop id, then by `StartupWMClass`, so the two
   names can split the icon and grouping.
   - Ship one entry whose id equals the app_id: `app.cratemusic.crate.desktop.desktop` with
     `Icon=app.cratemusic.crate.desktop`.
   - Write it at runtime only for AppImage.
   - Ship an SVG and a 48 px icon (only 16/32/64/128/256/512/1024 PNGs ship today).
   - Renaming the identifier to `app.cratemusic.crate` would be cleaner, but it moves the data
     dir (`~/.local/share/app.cratemusic.crate.desktop/offline-*`) and the keyring entries, so it
     needs a migration.
4. **Complete MPRIS.** Ryoku's bar, control center and popouts can seek, and the hover popout has
   shuffle and loop. Crate reports `CanSeek=false` and ignores `Seek`, `SetPosition`, `Shuffle`
   and `LoopStatus` (`linux_media_controls.rs:227-273`).
   - Add `Position`, the `Seeked` signal, `SetPosition` with the trackid, `Shuffle` and
     `LoopStatus`.
   - Report `Paused`, not `Stopped`, while a track is loaded. Ryoku's bar picker drops Stopped
     players and players with no metadata (`qsbar/modules/MprisSelect.qml`), so a stopped Crate
     disappears from the bar.
5. **Inhibit idle while playing.** hypridle honours D-Bus and systemd inhibitors but does not look
   at MPRIS, and Crate takes no inhibitor.
   - Hold an `org.freedesktop.portal.Inhibit` (idle) or `org.freedesktop.ScreenSaver.Inhibit`
     while audio plays, and release it on pause.

### P1: feel native

6. **Window chrome under a tiler.** The custom 36 px titlebar and the 12 px transparent CSS corners
   (`src/components/LinuxWindowTitlebar.tsx`, `src/linux-theme.css`) duplicate what Hyprland
   already draws: border, rounding and gaps.
   - Add a "system frame" mode that is on by default when the WM is not GNOME/KDE: no titlebar
     buttons, square corners, an opaque background.
   - Dragging stays, through `startDragging()`.
7. **Desktop notifications** on track change, as an opt-in setting. Ryoku's daemon supports these
   features:
   - the cover as an image hint, but only shown when `notifications.show_images` is on;
   - `replace-id`, so one card updates instead of stacking;
   - actions such as Next and Pause.
8. **A local control surface.** Today the only external control is MPRIS, `--crate-command` and
   OAuth deep links.
   - Add a socket at `$XDG_RUNTIME_DIR/crate/control.sock` (JSON lines): play/pause/seek, volume,
     like, queue, `play <uri>` and `search <q>`.
   - Extend `cratemusic://` to `track|album|artist|playlist/<id>`.
   - Items 9 and 12 build on this.
9. **Launcher search.** Ryoku's launcher runs rofi-script providers declared in
   `~/.config/ryoku/launcher-scripts.json` (`{keyword, name, exec:[argv]}`), typed as
   `<keyword> <query>`.
   - Add a `crate-desktop --launcher` mode that answers the rofi-script protocol from the socket
     or the API (rows with cover icons and `info` holding a `cratemusic://` URI).
   - Picking a row plays the item. Example: typing `cr nick cave` shows albums and tracks.
10. **Live theme.** It only re-reads the portal on focus (`src/lib/linux-theme.ts:24-35`).
    - Subscribe to the portal's `SettingChanged`.
    - Optionally follow the Ryoku palette, through either `~/.cache/ryoku/colors.json` (Material
      roles) or the palette bridge, which serves SSE on `127.0.0.1:47616/v1/events` and is off by
      default (Ryogami > Settings > Integrations).
11. **Monochrome tray icon** (`crate-tray-symbolic`). `SMOKE.md:58` already asks for it; the code
    uses the colour icon.
12. **Agent control.** The server MCP (`app/crate/mcp/`, 39 tools) has no playback tools.
    - A local `crate-desktop mcp` (stdio) over the control socket would let the desktop agent
      (Hermes, Claude) play, queue and search.
    - Ryoku has no command to register it: it goes in each harness's config
      (`~/.hermes/config.yaml` `mcp_servers:`, `claude mcp add`).

### P2: distribution and testing

13. **AUR package** (`crate-desktop-bin` from the release `.deb` or AppImage). Ryoku is Arch, and
    Ryostore can then list it.
14. **WebKitGTK on Wayland and NVIDIA.** Fall back to `WEBKIT_DISABLE_DMABUF_RENDERER=1` when the
    GPU or driver is known to be problematic. The visualizer is already noted as slow on Wayland.
15. **A Hyprland pass** in `docs/testing/` covering:
    - tiled, floating and fullscreen windows;
    - scale 1.5 and 2;
    - two monitors;
    - the dock grouping;
    - MPRIS in the bar and control center;
    - idle while playing.

## B. What Crate for Ryoku can do without app changes

- **Icons:** done. crate-icons draws the Crate logo for all three icon names.
- **Now playing in `crate-mark`:** read MPRIS through `Quickshell.Services.Mpris` (allowed in
  plugins), filtered on `org.mpris.MediaPlayer2.crate`. The panel would show cover, title and
  play/next controls next to "Open Crate". Seeking waits for A4.
- **Keybind:** a Hub > Keybinds row such as Super+M running `crate-desktop --crate-command=show`.
  Super+J is taken by Ryotunes.
- **Window rule:** a float/size rule for class `crate-desktop` (what 3.3.1 reports) until A1 and A2
  land, so Crate is usable now. Add it in Hub > Window Rules, or in `~/.config/hypr/user.lua` with
  `hl.window_rule({ match = { class = "^crate-desktop$" }, float = true, ... })`.
  A rice cannot carry a window rule directly; its `layers.appOverrides` covers opacity, blur and
  rounding.
- **Launcher provider** through `launcher-scripts.json`, once A9 exists.
