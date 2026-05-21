#!/usr/bin/python3
import os
import subprocess
import time
import re

LOG_PATH = "/tmp/bt_wifi_sync.log"

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
        paths = re.findall(r'object path "(/org/bluez/hci0/dev_[^"]+/[^"]*fd\d+)"', output)
        return paths[0] if paths else None
    except:
        return None

def get_bt_state(path):
    try:
        cmd = "dbus-send --system --dest=org.bluez --print-reply {} org.freedesktop.DBus.Properties.Get string:'org.bluez.MediaTransport1' string:'State'".format(path)
        output = subprocess.check_output(cmd, shell=True).decode()
        match = re.search(r'string "([^"]+)"', output)
        if match:
            return match.group(1)
    except:
        pass
    return None

def get_wifi_state():
    try:
        output = subprocess.check_output(["nmcli", "radio", "wifi"]).decode().strip()
        return output == "enabled"
    except:
        return None

def set_wifi(enabled):
    if get_wifi_state() == enabled:
        return
    state = "on" if enabled else "off"
    try:
        subprocess.call(["nmcli", "radio", "wifi", state])
        log("WiFi turned {}".format(state))
        
        # If we just turned WiFi ON, ensure DNS is fixed and Spotify is refreshed
        if enabled:
            # Wait for WiFi to associate and get an IP (up to 15 seconds)
            for _ in range(15):
                res = subprocess.run(["nmcli", "-t", "-f", "STATE", "g"], stdout=subprocess.PIPE, text=True)
                if "connected" in res.stdout:
                    log("WiFi connected. Fixing DNS and Spotifyd...")
                    # Force public DNS
                    subprocess.run(["sudo", "mount", "-o", "remount,rw", "/"])
                    with open("/tmp/resolv.conf.new", "w") as f:
                        f.write("nameserver 8.8.8.8\nnameserver 1.1.1.1\n")
                    subprocess.run(["sudo", "mv", "/tmp/resolv.conf.new", "/etc/resolv.conf"])
                    
                    # Restart Spotifyd to pick up the new connection
                    subprocess.run(["sudo", "initctl", "restart", "spotifyd"])
                    break
                time.sleep(1)
                
    except Exception as e:
        log("Error toggling WiFi: {}".format(e))

if os.path.exists(LOG_PATH):
    try: os.remove(LOG_PATH)
    except: pass

log("--- BT WiFi Sync Service Started ---")
last_wifi_enabled = get_wifi_state()

while True:
    path = get_active_transport()
    if path:
        state = get_bt_state(path)
        is_playing = (state == "active")
        
        if is_playing and last_wifi_enabled:
            set_wifi(False)
            last_wifi_enabled = False
        elif not is_playing and not last_wifi_enabled:
            set_wifi(True)
            last_wifi_enabled = True
    else:
        if not last_wifi_enabled:
            set_wifi(True)
            last_wifi_enabled = True

    time.sleep(2) # WiFi check can be slower
