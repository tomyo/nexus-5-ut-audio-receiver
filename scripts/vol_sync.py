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

def get_active_transport():
    try:
        cmd = "dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects"
        output = subprocess.check_output(cmd, shell=True).decode()
        paths = re.findall(r'object path "(/org/bluez/hci0/dev_[^"]+/[^"]*fd\d+)"', output)
        return paths[0] if paths else None
    except: return None

def get_bt_volume(path):
    try:
        cmd = "dbus-send --system --dest=org.bluez --print-reply {} org.freedesktop.DBus.Properties.Get string:'org.bluez.MediaTransport1' string:'Volume'".format(path)
        output = subprocess.check_output(cmd, shell=True).decode()
        match = re.search(r'uint16 (\d+)', output)
        if match: return int(match.group(1))
    except: pass
    return None

def ensure_loopback():
    try:
        sources = subprocess.check_output(["pactl", "list", "sources", "short"], env=ENV).decode()
        bt_source = next((line.split()[1] for line in sources.splitlines() if "bluez_source" in line), None)
        if not bt_source: return

        inputs = subprocess.check_output(["pactl", "list", "sink-inputs", "short"], env=ENV).decode()
        if "module-loopback" not in inputs:
            log("Loopback missing, recreating...")
            subprocess.call(["pactl", "load-module", "module-loopback", "source={}".format(bt_source), "sink=sink.primary", "sink_input_properties='media.role=music'"], env=ENV)
        
        # Ensure unmuted
        subprocess.call(["pactl", "list", "sink-inputs"], env=ENV) # Refresh
    except: pass

def set_volumes(vol_127):
    pa_vol = int((vol_127 / 127.0) * 100)
    pa_vol = max(0, min(100, pa_vol))
    SINK = "sink.primary"
    try:
        # Ensure card is in a2dp_sink mode
        cards = subprocess.check_output(["pactl", "list", "cards", "short"], env=ENV).decode()
        for line in cards.splitlines():
            if "bluez_card" in line:
                card_name = line.split()[1]
                subprocess.call(["pactl", "set-card-profile", card_name, "a2dp_sink"], env=ENV)

        subprocess.call(["pactl", "set-sink-volume", SINK, "{}%".format(pa_vol)], env=ENV)
        log("Volumes synced to {}%".format(pa_vol))
    except Exception as e:
        log("Error setting volume: {}".format(e))

if os.path.exists(LOG_PATH):
    try: os.remove(LOG_PATH)
    except: pass

log("--- Vol Sync Service Started ---")
last_vol = -1

while True:
    path = get_active_transport()
    if path:
        vol = get_bt_volume(path)
        if vol is not None and vol != last_vol:
            set_volumes(vol)
            last_vol = vol
    else: last_vol = -1

    ensure_loopback()
    time.sleep(0.5)
