"""A small MPRIS player on the fixture's private D-Bus."""

import json
import os
import signal
import sys
from pathlib import Path

from gi.repository import Gio, GLib, GLibUnix

name, value = sys.argv[1:3]
properties = {
    "org.mpris.MediaPlayer2": {
        "Identity": ("s", "Fixture"),
        "CanQuit": ("b", False),
        "CanRaise": ("b", False),
        "HasTrackList": ("b", False),
        "SupportedUriSchemes": ("as", []),
        "SupportedMimeTypes": ("as", []),
    },
    "org.mpris.MediaPlayer2.Player": {
        "PlaybackStatus": ("s", "Playing"),
        "Rate": ("d", 1.0),
        "MinimumRate": ("d", 1.0),
        "MaximumRate": ("d", 1.0),
        "Metadata": ("a{sv}", {
            "xesam:title": GLib.Variant("s", "Fixture song"),
            "mpris:trackid": GLib.Variant("o", "/track/fixture"),
            "mpris:length": GLib.Variant("x", 180_955_000),
        }),
        "Volume": ("d", 1.0),
        "CanControl": ("b", True),
        "CanPlay": ("b", True),
        "CanPause": ("b", True),
        "CanSeek": ("b", True),
        "CanGoNext": ("b", False),
        "CanGoPrevious": ("b", False),
        "Position": ("x", int(value)),
    },
}
xml = "<node>"
for iface, props in properties.items():
    xml += f'<interface name="{iface}">'
    for prop, (signature, _) in props.items():
        xml += f'<property name="{prop}" type="{signature}" access="read"/>'
    xml += "</interface>"
node = Gio.DBusNodeInfo.new_for_xml(xml + "</node>")


def read(bus, sender, path, interface, prop):
    if prop == "Position" and name.endswith(".paused") and Path("seek").exists():
        return GLib.Variant("x", 77_500_000)
    return GLib.Variant(*properties[interface][prop])


def register(bus, name):
    for iface in node.interfaces:
        bus.register_object("/org/mpris/MediaPlayer2", iface, None, read, None)


def accept_control(service, connection, source):
    state = {"type": "state", "protocol": 1, "player": {"shuffle": False, "repeat": "off"},
             "eq": {"enabled": False, "mode": "manual", "gains": [0] * 10}}
    connection.get_output_stream().write_all((json.dumps(state) + "\n").encode())
    connections.append(connection)
    return True


if name.endswith(".crate"):
    socket_path = Path(os.environ["XDG_RUNTIME_DIR"]) / "crate" / "control.sock"
    socket_path.parent.mkdir()
    connections = []
    control = Gio.SocketService.new()
    control.add_address(Gio.UnixSocketAddress.new(str(socket_path)), Gio.SocketType.STREAM,
                        Gio.SocketProtocol.DEFAULT, None)
    control.connect("incoming", accept_control)
    control.start()

owner = Gio.bus_own_name(Gio.BusType.SESSION, name, Gio.BusNameOwnerFlags.NONE,
                 register, lambda bus, name: print("ready", flush=True), None)
# Crate may drop its MPRIS name before its local control socket closes.
GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, lambda: Gio.bus_unown_name(owner))
GLib.MainLoop().run()
