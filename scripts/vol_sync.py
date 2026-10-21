#!/usr/bin/python3
import os
import subprocess
import time
import re

LOG_PATH = "/tmp/vol_sync.log"

def load_config():
    config = {"PA_UID": "32011"}
    try:
        with open("/home/phablet/config.env", "r") as f:
            for line in f:
                if "=" in line and not line.startswith("#"):
                    k, v = line.strip().split("=", 1)
                    config[k] = v.strip('"')
    except: pass
    return config

CONFIG = load_config()
ENV = os.environ.copy()
ENV["PULSE_RUNTIME_PATH"] = "/run/user/{}/pulse/".format(CONFIG.get("PA_UID", "32011"))

def log(msg):
    try:
        with open(LOG_PATH, "a") as f:
            f.write("{} - {}\n".format(time.strftime("%H:%M:%S"), msg))
    except: pass

def run_cmd(cmd, check=False):
    try:
        if check:
            return subprocess.check_output(cmd, shell=True, env=ENV).decode()
        else:
            subprocess.call(cmd, shell=True, env=ENV)
    except: pass
    return ""

def get_active_transport():
    output = run_cmd("dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects", check=True)
    paths = re.findall(r'object path "(/org/bluez/hci0/dev_[^"]+/[^"]*fd\d+)"', output)
    return paths[0] if paths else None

def get_bt_volume(path):
    output = run_cmd("dbus-send --system --dest=org.bluez --print-reply {} org.freedesktop.DBus.Properties.Get string:'org.bluez.MediaTransport1' string:'Volume'".format(path), check=True)
    match = re.search(r'uint16 (\d+)', output)
    return int(match.group(1)) if match else None

def set_bt_volume(path, vol_127):
    vol_127 = max(0, min(127, vol_127))
    run_cmd("dbus-send --system --dest=org.bluez --print-reply {} org.freedesktop.DBus.Properties.Set string:'org.bluez.MediaTransport1' string:'Volume' variant:uint16:{}".format(path, vol_127))

def get_sink_volume():
    output = run_cmd("pactl list sinks", check=True)
    for line in output.splitlines():
        if "sink.primary" in line:
            break
    else:
        return None
    for line in output.splitlines():
        if "Volume:" in line and "front-left" in line:
            match = re.search(r'(\d+) / *(\d+)%', line)
            if match:
                return int(match.group(2))
    return None

def set_sink_volume(vol_127):
    pa_vol = int((vol_127 / 127.0) * 100)
    pa_vol = max(0, min(100, pa_vol))
    SINK = "sink.primary"
    # Ensure card is in a2dp_sink mode
    cards = run_cmd("pactl list cards short", check=True)
    for line in cards.splitlines():
        if "bluez_card" in line:
            card_name = line.split()[1]
            run_cmd("pactl set-card-profile {} a2dp_sink".format(card_name))
    run_cmd("pactl set-sink-volume {} {}%".format(SINK, pa_vol))
    log("Volumes synced to {}%".format(pa_vol))
    return pa_vol

def get_bt_a2dp_source():
    """Return the Bluetooth A2DP source name if it exists and is RUNNING, else None."""
    try:
        output = run_cmd("pactl list sources", check=True)
        current_name = None
        current_state = None
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("Name:"):
                current_name = line.split("Name:", 1)[1].strip()
            elif line.startswith("State:"):
                current_state = line.split("State:", 1)[1].strip()
                if current_name and "bluez_source" in current_name and current_state == "RUNNING":
                    return current_name
                current_name = None
                current_state = None
    except: pass
    return None

def ensure_loopback():
    try:
        bt_source = get_bt_a2dp_source()
        if not bt_source:
            # No active Bluetooth A2DP source - don't create fallback loopback
            return

        # Base name without .N suffix to catch policy-created variants
        bt_base = bt_source.split('.')[0]

        modules = run_cmd("pactl list modules short", check=True)
        bridge_ready = False
        for line in modules.splitlines():
            fields = line.split("\t", 3)
            if len(fields) < 3 or fields[1] != "module-loopback":
                continue
            args = fields[2].replace('"', '').split()
            # Check if this loopback uses our Bluetooth device (base name match)
            source_arg = next((a for a in args if a.startswith("source=")), "")
            if not source_arg.startswith("source=" + bt_base):
                continue
            if "latency_msec=200" in args:
                bridge_ready = True
            else:
                # Policy-created or old loopback - unload it
                run_cmd("pactl unload-module {}".format(fields[0]))
        if not bridge_ready:
            log("Creating Bluetooth loopback with 200 ms target latency...")
            run_cmd("pactl load-module module-loopback source={} sink=sink.primary latency_msec=200 sink_input_properties=media.role=music".format(bt_source))
    except: pass

if os.path.exists(LOG_PATH):
    try: os.remove(LOG_PATH)
    except: pass

log("--- Vol Sync Service Started ---")
last_bt_vol = -1
last_sink_vol = -1
last_bt_sync_time = 0

while True:
    path = get_active_transport()
    if path:
        bt_vol = get_bt_volume(path)
        sink_vol = get_sink_volume()

        # Bluetooth -> Nexus sync
        if bt_vol is not None and bt_vol != last_bt_vol:
            set_sink_volume(bt_vol)
            last_bt_vol = bt_vol
            last_sink_vol = sink_vol  # Expected sink volume after sync
            last_bt_sync_time = time.time()

        # Nexus -> Bluetooth sync (bidirectional)
        # Only if sink volume changed AND it wasn't from our recent Bluetooth sync
        elif sink_vol is not None and sink_vol != last_sink_vol:
            # Ignore sink changes that happen within 1s of our Bluetooth sync (avoid loop)
            if time.time() - last_bt_sync_time > 1.0:
                bt_target = int((sink_vol / 100.0) * 127)
                set_bt_volume(path, bt_target)
                log("Nexus volume {}% -> Bluetooth {}".format(sink_vol, bt_target))
                last_bt_vol = bt_target
            last_sink_vol = sink_vol
    else:
        last_bt_vol = -1
        last_sink_vol = -1

    ensure_loopback()
    time.sleep(0.5)