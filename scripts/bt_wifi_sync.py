#!/usr/bin/python3
"""Disable Wi-Fi during incoming Bluetooth playback; leave DNS to NetworkManager."""
import subprocess
import time

LOG_PATH = "/tmp/bt_wifi_sync.log"


def log(message):
    with open(LOG_PATH, "a") as output:
        output.write("{} - {}\n".format(time.strftime("%H:%M:%S"), message))


def is_streaming(objects):
    return any(
        interfaces.get("org.bluez.MediaTransport1", {}).get("State") == "active"
        and interfaces["org.bluez.MediaTransport1"].get("UUID")
        == "0000110b-0000-1000-8000-00805f9b34fb"
        for interfaces in objects.values())


def set_wifi(enabled):
    current = subprocess.check_output(
        ["nmcli", "radio", "wifi"], timeout=3).decode().strip()
    desired = "enabled" if enabled else "disabled"
    if current != desired:
        subprocess.check_call(
            ["nmcli", "radio", "wifi", "on" if enabled else "off"], timeout=5)
        log("Wi-Fi {}".format(desired))


def main():
    import dbus

    while True:
        try:
            bus = dbus.SystemBus()
            manager = dbus.Interface(bus.get_object("org.bluez", "/"),
                                     "org.freedesktop.DBus.ObjectManager")
            set_wifi(not is_streaming(manager.GetManagedObjects(timeout=3)))
        except (dbus.DBusException, subprocess.SubprocessError, OSError) as error:
            log("Wi-Fi sync failed: {}".format(error))
        time.sleep(2)


if __name__ == "__main__":
    main()
