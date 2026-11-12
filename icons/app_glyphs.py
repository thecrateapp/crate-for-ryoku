"""Which glyph each app gets in crate-icons and crate-icons-auto.

Brands first: an app whose identity is its logo (Firefox, Slack, Steam) gets
its brand mark, drawn in Crate's colours by build_icons.brand_svg. BRANDS names
the mark: a Tabler Icons line brand (MIT) where Tabler has one, a Simple Icons
silhouette (CC0) otherwise, and RECOLOR where neither has a free mark: that app
keeps its own icon, recoloured into the Crate palette by crateize.py.
BRAND_PREFIXES catches names that carry an install id, such as the
jetbrains-phpstorm-<uuid> icons JetBrains Toolbox writes. brand_export.mjs
vendors exactly the marks this module uses (BRAND_KEYS).

Everything else gets a Solar line-duotone glyph (white ink with one cyan
layer). Names are Solar's PascalCase component names (@solar-icons/react-perf);
solar_export_perf.mjs vendors exactly the set this module uses (GLYPHS). A
brand app's APPS entry is its Solar fallback.

APPS and BRANDS match the desktop entry's Icon= name first, then its file name
without .desktop. CATEGORIES is the fallback for anything installed later: the
first freedesktop category of the entry that has a glyph here wins.
"""

import re

APPS = {
    # browsers and the web
    "firefox": "Global", "google-chrome": "Planet", "chromium": "Planet", "org.gnome.Epiphany": "Compass",
    "org.gnome.BrowserConnector": "Link", "org.gnome.Shell.CaptivePortal": "Login",
    # talk
    "slack": "HashtagSquare", "org.telegram.desktop": "Plain", "org.mozilla.Thunderbird": "Letter",
    "org.gnome.Evolution-alarm-notify": "Bell", "org.gnome.Contacts": "UserId",
    "chatgpt": "ChatRoundLine", "claude-desktop": "Stars",
    # code
    "CMakeSetup": "CodeScan", "antigravity": "CodeSquare", "gvim": "CodeFile", "nvim": "Code",
    "jetbrains-toolbox": "Box", "postman": "Rocket", "mongodb-compass": "Database", "designer": "RulerPen",
    "linguist": "Translation", "assistant": "Notebook", "qdbusviewer": "Routing", "org.gnome.Meld": "TransferHorizontal",
    "electron37": "Widget", "org.quickshell": "Widget2", "org.gnome.Terminal.Preferences": "Programming",
    # media
    "mpv": "PlayCircle", "video-x-generic": "VideoFrame", "qvidcap": "Videocamera", "qv4l2": "Videocamera",
    "tidal-hifi": "HeadphonesRound", "re.fossplant.songrec": "Soundwave", "ryotunes": "MusicNotes",
    "org.nicotine_plus.Nicotine": "Download", "rygel": "Screencast", "audio-input-microphone": "Microphone",
    "com.github.wwmm.easyeffects": "Tuning2",
    # notes and office
    "obsidian": "Notebook", "onlyoffice-desktopeditors": "Documents", "appointment-soon": "Calendar",
    # games
    "steam": "Gamepad", "wine": "WindowFrame", "winetricks": "WindowFrame",
    # system and hardware
    "nvidia-settings": "CpuBolt", "hwloc": "Cpu", "org.openrgb.OpenRGB": "LightbulbBolt",
    "btrfs-assistant": "Database", "drive-removable-media": "FlashDrive", "qemu": "Server",
    "ryovm": "Server2", "ryostore": "Bag", "ryomanager": "Box", "ryoku-hub": "Settings",
    "rashin-app": "Compass", "vicinae": "Magnifier", "localsend": "Share",
    "org.cachyos.hello": "Home", "org.cachyos.KernelManager": "Layers", "org.cachyos.scx-manager": "Routing2",
    "cachyos-pi": "Box", "org.gnome.Mutter.Mdk": "Monitor", "org.gnome.Connections": "MonitorSmartphone",
    "org.gnome.NautilusPreviewer": "Eye", "org.gnome.PowerStats": "BatteryCharge", "org.gnome.Tour": "Flag",
    "org.gnome.Shell.Extensions": "Widget4", "org.gnome.tweaks": "Tuning", "org.gnome.Tecla": "Keyboard",
    "org.gnome.SimpleScan": "Scanner", "org.gnome.Maps": "Map", "map-globe": "Map", "mark-location-symbolic": "MapPoint",
    "org.freedesktop.MalcontentControl": "ShieldUser", "security-medium": "Shield", "kwalletmanager": "Wallet",
    "pinentry": "Key", "orca": "Accessibility", "ibus": "Keyboard", "ibus-setup": "Keyboard",
    "bluetooth": "Bluetooth", "network-wireless-symbolic": "WiFiRouter", "gnome-nettool": "ServerSquare",
    "cups": "Printer", "printer": "Printer", "document-print-preview": "Printer",
    "gnome-color-manager": "Pallete2", "application-vnd.iccprofile": "Pallete2",
    "preferences-desktop-theme": "Palette", "application-x-executable": "Widget",
    "applications-system-symbolic": "Settings", "org.gnome.goa-daemon-symbolic": "UserCircle",
    # GNOME Settings panels
    "org.gnome.Settings-about-symbolic": "InfoCircle", "org.gnome.Settings-accessibility-symbolic": "Accessibility",
    "org.gnome.Settings-appearance-symbolic": "Palette", "org.gnome.Settings-applications-symbolic": "Widget",
    "org.gnome.Settings-bluetooth-symbolic": "Bluetooth", "org.gnome.Settings-color-symbolic": "Pallete2",
    "org.gnome.Settings-display-symbolic": "Monitor", "org.gnome.Settings-keyboard-symbolic": "Keyboard",
    "org.gnome.Settings-mobile-network-symbolic": "Smartphone", "org.gnome.Settings-mouse-symbolic": "Mouse",
    "org.gnome.Settings-multitasking-symbolic": "Widget4", "org.gnome.Settings-network-symbolic": "WiFiRouterRound",
    "org.gnome.Settings-notifications-symbolic": "Bell", "org.gnome.Settings-online-accounts-symbolic": "UserCircle",
    "org.gnome.Settings-power-symbolic": "BatteryCharge", "org.gnome.Settings-printers-symbolic": "Printer",
    "org.gnome.Settings-privacy-symbolic": "ShieldKeyhole", "org.gnome.Settings-region-symbolic": "Global",
    "org.gnome.Settings-search-symbolic": "Magnifier", "org.gnome.Settings-sharing-symbolic": "Share",
    "org.gnome.Settings-sound-symbolic": "VolumeLoud", "org.gnome.Settings-system-symbolic": "Settings",
    "org.gnome.Settings-time-symbolic": "ClockCircle", "org.gnome.Settings-users-symbolic": "UsersGroupRounded",
    "org.gnome.Settings-wacom-symbolic": "Pen", "org.gnome.Settings-wellbeing-symbolic": "Heart",
}

# freedesktop main and additional categories, most specific first
CATEGORIES = [
    ("WebBrowser", "Global"), ("Email", "Letter"), ("InstantMessaging", "ChatRoundDots"), ("Chat", "ChatRoundDots"),
    ("IDE", "CodeSquare"), ("TextEditor", "PenNewSquare"), ("TerminalEmulator", "Programming"),
    ("Database", "Database"), ("Development", "Code"),
    ("Player", "PlayCircle"), ("Music", "MusicNotes"), ("Audio", "Soundwave"), ("Video", "VideoFrame"),
    ("AudioVideo", "PlayCircle"), ("Photography", "Camera"), ("Graphics", "Pallete2"),
    ("Game", "Gamepad"), ("Office", "Documents"), ("Calendar", "Calendar"), ("Science", "TestTube"),
    ("Education", "Notebook"), ("FileTransfer", "Download"), ("Network", "Global"),
    ("Security", "Shield"), ("Monitor", "Pulse"), ("Settings", "Tuning"), ("HardwareSettings", "Cpu"),
    ("Accessibility", "Accessibility"), ("Archiving", "Archive"), ("FileManager", "FolderWithFiles"),
    ("Emulator", "Gamepad"), ("System", "Settings"), ("Utility", "Widget"),
]

GLYPHS = sorted(set(APPS.values()) | {g for _, g in CATEGORIES})

# ---------------------------------------------------------------- brands

RECOLOR = ("recolor", None)  # no free mark: keep the app's own icon, recoloured


def _tabler(name):
    return ("tabler", "brand-" + name)


def _si(slug):
    return ("simple-icons", slug)


BRANDS = {
    # Tabler line brands
    "firefox": _tabler("firefox"), "firefox-esr": _tabler("firefox"),
    "firefox-developer-edition": _tabler("firefox"), "org.mozilla.firefox": _tabler("firefox"),
    "google-chrome": _tabler("chrome"), "google-chrome-beta": _tabler("chrome"),
    "google-chrome-unstable": _tabler("chrome"), "com.google.Chrome": _tabler("chrome"),
    "slack": _tabler("slack"), "com.slack.Slack": _tabler("slack"),
    "org.telegram.desktop": _tabler("telegram"), "telegram": _tabler("telegram"),
    "telegram-desktop": _tabler("telegram"),
    "steam": _tabler("steam"), "com.valvesoftware.Steam": _tabler("steam"),
    "chatgpt": _tabler("openai"),
    "tidal-hifi": _tabler("tidal"), "com.mastermindzh.tidal-hifi": _tabler("tidal"),
    "mongodb-compass": _tabler("mongodb"),
    # Simple Icons silhouettes
    "claude-desktop": _si("claude"), "com.anthropic.Claude": _si("claude"), "claude": _si("claude"),
    "org.mozilla.Thunderbird": _si("thunderbird"), "thunderbird": _si("thunderbird"),
    "net.thunderbird.Thunderbird": _si("thunderbird"),
    "obsidian": _si("obsidian"), "md.obsidian.Obsidian": _si("obsidian"),
    "postman": _si("postman"), "com.getpostman.Postman": _si("postman"),
    "onlyoffice-desktopeditors": _si("onlyoffice"), "org.onlyoffice.desktopeditors": _si("onlyoffice"),
    "mpv": _si("mpv"), "io.mpv.Mpv": _si("mpv"),
    "gvim": _si("vim"), "vim": _si("vim"),
    # Neovim wears Vim's mark: its own (CC BY-SA 3.0) would put share-alike art
    # in the theme, and Vim's is the family it comes from
    "nvim": _si("vim"), "neovim": _si("vim"), "io.neovim.nvim": _si("vim"),
    "wine": _si("wine"), "winetricks": _si("wine"),
    "nvidia-settings": _si("nvidia"),
    "qemu": _si("qemu"),
    "CMakeSetup": _si("cmake"), "cmake-gui": _si("cmake"),
    "localsend": _si("localsend"), "org.localsend.localsend_app": _si("localsend"),
    # the welcome app is CachyOS itself; its other tools keep their Solar glyphs
    "org.cachyos.hello": _si("cachyos"),
    # no free mark: Antigravity has none, so its own icon is recoloured on the machine
    "antigravity": RECOLOR,
}

# name patterns matched from the start, most specific first: JetBrains Toolbox
# names its icons jetbrains-<ide>-<install id>; distro packages use the bare IDE
# name (phpstorm, webstorm-eap); every other JetBrains IDE gets the JetBrains mark
BRAND_PREFIXES = [
    (r"(jetbrains-)?phpstorm", _si("phpstorm")),
    (r"(jetbrains-)?webstorm", _si("webstorm")),
    (r"jetbrains-", _si("jetbrains")),
    (r"electron\d*$", _si("electron")),  # the runtime (electron, electron37), not electron-cash
]

BRAND_KEYS = sorted({f"{src}/{name}" for src, name in list(BRANDS.values()) + [b for _, b in BRAND_PREFIXES]
                     if src != "recolor"})


def kebab(name):
    """PascalCase Solar name -> the kebab key the vendored JSON uses."""
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", name)
    return re.sub(r"([A-Z])([A-Z][a-z])", r"\1-\2", s).lower()


def _stem(entry_file):
    return entry_file[:-8] if entry_file.endswith(".desktop") else entry_file


def brand_for(icon, entry_file):
    """(source, name) of the app's brand mark, RECOLOR, or None for a generic app."""
    stem = _stem(entry_file)
    for n in (icon, stem):
        if n in BRANDS:
            return BRANDS[n]
    for n in (icon, stem):
        for pattern, brand in BRAND_PREFIXES:
            if re.match(pattern, n):
                return brand
    return None


def icon_for(icon, entry_file, categories):
    """What to draw for one app: ("brand", "source/name"), ("solar", kebab), RECOLOR or None."""
    brand = brand_for(icon, entry_file)
    if brand == RECOLOR:
        return RECOLOR
    if brand:
        return ("brand", "/".join(brand))
    glyph = glyph_for(icon, entry_file, categories)
    return ("solar", glyph) if glyph else None


def glyph_for(icon, entry_file, categories):
    """The Solar glyph (kebab) for one app, or None to keep its recoloured icon."""
    stem = _stem(entry_file)
    name = APPS.get(icon) or APPS.get(stem)
    if not name:
        cats = set(categories)
        name = next((g for c, g in CATEGORIES if c in cats), None)
    return kebab(name) if name else None
