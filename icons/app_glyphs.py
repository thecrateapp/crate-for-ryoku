"""Which Solar glyph each app gets in crate-icons-auto.

crateize.py draws an installed app in Crate's icon language (a Solar
line-duotone glyph, white ink with one cyan layer) when this module names a
glyph for it, and only recolours the app's own icon when it does not. Names are
Solar's PascalCase component names (@solar-icons/react-perf); solar_export_perf.mjs
vendors exactly the set this module uses (GLYPHS).

APPS matches the desktop entry's Icon= name first, then its file name without
.desktop. CATEGORIES is the fallback for anything installed later: the first
freedesktop category of the entry that has a glyph here wins.
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


def kebab(name):
    """PascalCase Solar name -> the kebab key the vendored JSON uses."""
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", name)
    return re.sub(r"([A-Z])([A-Z][a-z])", r"\1-\2", s).lower()


def glyph_for(icon, entry_file, categories):
    """The Solar glyph (kebab) for one app, or None to keep its recoloured icon."""
    stem = entry_file[:-8] if entry_file.endswith(".desktop") else entry_file
    name = APPS.get(icon) or APPS.get(stem)
    if not name:
        cats = set(categories)
        name = next((g for c, g in CATEGORIES if c in cats), None)
    return kebab(name) if name else None
