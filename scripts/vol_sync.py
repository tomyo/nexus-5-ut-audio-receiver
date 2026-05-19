import os
import subprocess
import time
import re

JACK_STATE_PATH = "/sys/class/switch/h2w/state"
LOG_PATH = "/tmp/vol_sync.log"

# PulseAudio environment for phablet user
ENV = os.environ.copy()
ENV["PULSE_RUNTIME_PATH"] = "/run/user/32011/pulse/"

def log(msg):
    try:
        with open(LOG_PATH, "a") as f:
            f.write("{} - {}\n".format(time.strftime("%H:%M:%S"), msg))
    except:
        pass

def get_active_transport():
    try:
        cmd = "dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects"
        output = subprocess.check_output(cmd, shell=True).decode()
        paths = re.findall(r'object path "(/org/bluez/hci0/dev_[^"]+/fd\d+)"', output)
        return paths[0] if paths else None
    except:
        return None

def get_bt_volume(path):
    try:
        cmd = "dbus-send --system --dest=org.bluez --print-reply {} org.freedesktop.DBus.Properties.Get string:'org.bluez.MediaTransport1' string:'Volume'".format(path)
        output = subprocess.check_output(cmd, shell=True).decode()
        match = re.search(r'uint16 (\d+)', output)
        if match:
            return int(match.group(1))
    except:
        pass
    return None

def ensure_loopback():
    try:
        # 1. Get the bluez source name
        sources = subprocess.check_output(["pactl", "list", "sources", "short"], env=ENV).decode()
        bt_source = None
        for line in sources.splitlines():
            if "bluez_source" in line:
                bt_source = line.split()[1]
                break
        
        if not bt_source:
            return

        # 2. Check if loopback already exists
        inputs = subprocess.check_output(["pactl", "list", "sink-inputs", "short"], env=ENV).decode()
        if "module-loopback" not in inputs:
            log("Loopback missing, recreating...")
            subprocess.call(["pactl", "load-module", "module-loopback", 
                           "source={}".format(bt_source), 
                           "sink=sink.primary", 
                           "sink_input_properties='media.role=music'"], env=ENV)
        
        # 3. Ensure all loopbacks are unmuted and at 100%
        inputs_full = subprocess.check_output(["pactl", "list", "sink-inputs"], env=ENV).decode()
        # Simple parser for pactl output
        current_id = None
        for line in inputs_full.splitlines():
            if "Sink Input #" in line:
                current_id = line.split("#")[1]
            if "Driver: module-loopback.c" in line and current_id:
                subprocess.call(["pactl", "set-sink-input-mute", current_id, "0"], env=ENV)
                # Note: We keep the input at 100% and control master volume via sink.primary
                subprocess.call(["pactl", "set-sink-input-volume", current_id, "100%"], env=ENV)

    except Exception as e:
        log("Error in ensure_loopback: {}".format(e))

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
                # Check current profile
                card_info = subprocess.check_output(["pactl", "list", "cards"], env=ENV).decode()
                if "Active Profile: a2dp_sink" not in card_info:
                    log("Forcing card to a2dp_sink...")
                    subprocess.call(["pactl", "set-card-profile", card_name, "a2dp_sink"], env=ENV)

        subprocess.call(["pactl", "set-sink-volume", SINK, "{}%".format(pa_vol)], env=ENV)
        log("Volumes synced to {}% (BT {})".format(pa_vol, vol_127))
    except Exception as e:
        log("Error setting volume: {}".format(e))

def check_jack():
    try:
        with open(JACK_STATE_PATH, 'r') as f:
            return int(f.read().strip())
    except:
        return -1

def set_pa_port(jack_active):
    # Port names for Nexus 5 / Hammerhead
    port = "[Out] Headphones" if jack_active else "[Out] Speaker"
    SINK = "0" # Using index to be safe
    try:
        subprocess.call(["pactl", "set-sink-port", SINK, port], env=ENV)
        log("Port switched to: {}".format(port))
    except Exception as e:
        log("Error switching port: {}".format(e))

last_vol = -1
last_jack = -1

if os.path.exists(LOG_PATH):
    try: os.remove(LOG_PATH)
    except: pass

log("--- Universal Sync Utility v3 Started ---")

while True:
    path = get_active_transport()
    if path:
        vol = get_bt_volume(path)
        if vol is not None and vol != last_vol:
            set_volumes(vol)
            last_vol = vol
    else:
        last_vol = -1

    ensure_loopback()

    jack = check_jack()
    if jack != last_jack:
        set_pa_port(jack > 0)
        last_jack = jack

    time.sleep(0.5)
