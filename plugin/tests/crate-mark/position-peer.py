"""Minimal MPRIS position property on the fixture's private D-Bus."""

import sys
from pathlib import Path

from gi.repository import Gio, GLib

name, value = sys.argv[1:3]
iface = Gio.DBusNodeInfo.new_for_xml("""
<node><interface name="org.mpris.MediaPlayer2.Player">
  <property name="Position" type="x" access="read"/>
</interface></node>
""").interfaces[0]


def read(bus, sender, path, interface, prop):
    print("get", flush=True)
    if name.endswith(".paused") and Path("seek").exists():
        return GLib.Variant("x", 77_500_000)
    return GLib.Variant("x", int(value))


def ready(bus, name):
    bus.register_object("/org/mpris/MediaPlayer2", iface, None, read, None)
    print("ready", flush=True)


Gio.bus_own_name(Gio.BusType.SESSION, name, Gio.BusNameOwnerFlags.NONE, ready, None, None)
GLib.MainLoop().run()
