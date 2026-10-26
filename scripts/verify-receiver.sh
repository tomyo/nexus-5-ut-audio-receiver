#!/bin/bash

# Assert that the phone is in the state the installers intend, without changing
# anything. Run it after a replay of setup.sh / setup-shairport.sh to prove the
# scripts are idempotent, and after a reboot to prove the receiver survived.
#
#   bash scripts/verify-receiver.sh
#   PHONE=phablet@192.168.11.9 bash scripts/verify-receiver.sh
#
# Exit status is 0 only when every check passes.

set -u

# Load configuration first: it holds SUDO_PIN and PHONE_HOST.
if [ -f "scripts/config.env" ]; then
    # shellcheck disable=SC1091
    source scripts/config.env
else
    echo "Error: scripts/config.env not found! Run this from the repository root." >&2
    exit 1
fi

PHONE="${PHONE:-phablet@${PHONE_HOST:-192.168.11.9}}"
MDNS_NAME="${DEVICE_NAME,,}"

# Run a command on the phone as root.
as_root() {
    ssh -o BatchMode=yes "$PHONE" "echo $SUDO_PIN | sudo -S -p '' $*"
}

pass=0
fail=0

check() { # label  expected  actual
    if [ "$2" = "$3" ]; then
        printf 'PASS  %-30s %s\n' "$1" "$3"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-30s expected=%s got=%s\n' "$1" "$2" "${3:-<empty>}"
        fail=$((fail + 1))
    fi
}

echo "--- Receiver state: $DEVICE_NAME ($PHONE) ---"

# ---------- mDNS ----------
check "avahi override file" absent \
    "$(ssh -o BatchMode=yes "$PHONE" '[ -f /etc/init/avahi-daemon.override ] && echo present || echo absent')"

check "pinned mDNS host-name" "$MDNS_NAME" \
    "$(ssh -o BatchMode=yes "$PHONE" "grep -m1 '^[[:space:]]*host-name=' /etc/avahi/avahi-daemon.conf 2>/dev/null | cut -d= -f2 | tr -d ' '")"

check "avahi-daemon running" yes \
    "$(as_root 'initctl status avahi-daemon' 2>/dev/null | grep -qc 'start/running' && echo yes || echo no)"

check "AirPlay advert present" yes \
    "$(ssh -o BatchMode=yes "$PHONE" "avahi-browse -rt _raop._tcp 2>/dev/null | grep -qc '^=' && echo yes || echo no")"

# ---------- shairport-sync ----------
check "shairport-sync process" yes \
    "$(ssh -o BatchMode=yes "$PHONE" 'pgrep -x shairport-sync >/dev/null && echo yes || echo no')"

check "shairport-sync job" yes \
    "$(as_root 'initctl status shairport-sync' 2>/dev/null | grep -qc 'start/running' && echo yes || echo no)"

# ---------- PulseAudio ----------
# The live startup script is whatever daemon.conf pins, not default.pa.
PA_SCRIPT=$(ssh -o BatchMode=yes "$PHONE" \
    "cat /home/phablet/.config/pulse/daemon.conf /etc/pulse/daemon.conf 2>/dev/null | grep -m1 '^[[:space:]]*default-script-file' | cut -d= -f2 | tr -d ' '" | tr -d '\r')
[ -n "$PA_SCRIPT" ] || PA_SCRIPT=/etc/pulse/default.pa
echo "INFO  live PulseAudio script       $PA_SCRIPT"

check "suspend-on-idle load line" 0 \
    "$(ssh -o BatchMode=yes "$PHONE" "grep -c '^load-module module-suspend-on-idle$' $PA_SCRIPT 2>/dev/null || true" | tr -d '\r')"

check "suspend-on-idle module" 0 \
    "$(ssh -o BatchMode=yes "$PHONE" 'export PULSE_RUNTIME_PATH=/run/user/32011/pulse/; pactl list short modules | grep -c suspend-on-idle || true' | tr -d '\r')"

# ---------- Wi-Fi ----------
check "wifi power save" "Power save: off" \
    "$(ssh -o BatchMode=yes "$PHONE" 'iw dev wlan0 get power_save 2>/dev/null' | tr -d '\r')"

# ---------- retired Spotify daemon ----------
check "go-librespot binary" absent \
    "$(ssh -o BatchMode=yes "$PHONE" '[ -e /usr/bin/go-librespot ] && echo present || echo absent')"

check "spotifyd job file" absent \
    "$(ssh -o BatchMode=yes "$PHONE" '[ -e /etc/init/spotifyd.conf ] && echo present || echo absent')"

check "spotify-connect adverts" 0 \
    "$(ssh -o BatchMode=yes "$PHONE" 'timeout 6 avahi-browse -t _spotify-connect._tcp 2>/dev/null | grep -c "^=" || true' | tr -d '\r')"

# ---------- resident jobs ----------
for job in vol-sync jack-sense keep-awake bt-agent bt-wifi-sync wifi-powersave; do
    check "job: $job installed" yes \
        "$(ssh -o BatchMode=yes "$PHONE" "[ -f /etc/init/$job.conf ] && echo yes || echo no")"
done

# ---------- informational ----------
JACK=$(ssh -o BatchMode=yes "$PHONE" 'cat /sys/class/switch/h2w/state 2>/dev/null' | tr -d '\r')
PORT=$(ssh -o BatchMode=yes "$PHONE" \
    'export PULSE_RUNTIME_PATH=/run/user/32011/pulse/; pactl list sinks 2>/dev/null | grep -m1 "Active Port" | cut -d: -f2 | tr -d " "' | tr -d '\r')
echo "INFO  jack state / active port     ${JACK:-?} / ${PORT:-?}"

echo
if [ "$fail" -eq 0 ]; then
    echo "All $pass checks passed."
    exit 0
fi
echo "$pass passed, $fail FAILED."
exit 1
