#!/usr/bin/python3
"""Map the active Bluetooth sender's volume to the wired output only."""
import os
import subprocess
import time

LOG_PATH = "/tmp/vol_sync.log"


def pulse_env():
    uid = "32011"
    try:
        with open("/home/phablet/config.env") as config:
            for line in config:
                if line.startswith("PA_UID="):
                    uid = line.split("=", 1)[1].strip().strip('\"\'')
    except FileNotFoundError:
        pass
    env = os.environ.copy()
    env["PULSE_RUNTIME_PATH"] = "/run/user/{}/pulse/".format(uid)
    return env


def active_volume(objects):
    candidates = []
    for path, interfaces in objects.items():
        transport = interfaces.get("org.bluez.MediaTransport1", {})
        if (transport.get("State") == "active"
                and transport.get("UUID") == "0000110b-0000-1000-8000-00805f9b34fb"
                and "Volume" in transport):
            volume = int(transport["Volume"])
            if 0 <= volume <= 127:
                candidates.append((str(path), volume))
    # A shared output has no unambiguous volume owner with multiple senders.
    return candidates[0] if len(candidates) == 1 else None


def sync_volume(objects, previous, env):
    current = active_volume(objects)
    if current is not None and current != previous:
        percent = int(current[1] * 100 / 127)
        subprocess.check_call(
            ["pactl", "set-sink-volume", "sink.primary", "{}%".format(percent)],
            env=env, timeout=3)
    return current


def log(message):
    with open(LOG_PATH, "a") as output:
        output.write("{} - {}\n".format(time.strftime("%H:%M:%S"), message))


def main():
    import dbus

    env = pulse_env()
    previous = None
    last_error = None
    log("Volume-only sync started; profiles and bridges are not modified")
    while True:
        try:
            bus = dbus.SystemBus()
            manager = dbus.Interface(bus.get_object("org.bluez", "/"),
                                     "org.freedesktop.DBus.ObjectManager")
            current = sync_volume(manager.GetManagedObjects(timeout=3), previous, env)
            if current is not None and current != previous:
                log("Bluetooth volume {} -> output {}%".format(
                    current[1], int(current[1] * 100 / 127)))
            previous = current
            last_error = None
        except (dbus.DBusException, subprocess.SubprocessError, OSError) as error:
            if str(error) != last_error:
                log("Volume sync failed: {}".format(error))
                last_error = str(error)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
