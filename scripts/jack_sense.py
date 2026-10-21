#!/usr/bin/python3
import os
import subprocess
import time

JACK_STATE_PATH = "/sys/class/switch/h2w/state"
LOG_PATH = "/tmp/jack_sense.log"

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

def check_jack():
    try:
        with open(JACK_STATE_PATH, 'r') as f:
            return int(f.read().strip())
    except: return -1

def set_pa_port(jack_active):
    port = "output-wired_headphone" if jack_active else "output-speaker"
    SINK = "sink.primary"
    try:
        subprocess.check_call(["pactl", "set-sink-port", SINK, port], env=ENV, timeout=3)
        log("Port switched to: {}".format(port))
        return True
    except Exception as e:
        log("Error switching port: {}".format(e))
    return False

def main():
    log("--- Jack Sense Service Started ---")
    last_jack = -1
    while True:
        jack = check_jack()
        if jack >= 0 and jack != last_jack:
            if set_pa_port(jack > 0):
                last_jack = jack
        time.sleep(1)


if __name__ == "__main__":
    main()
