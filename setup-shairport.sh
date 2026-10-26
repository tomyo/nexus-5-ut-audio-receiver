#!/bin/bash

# Nexus 5 Ubuntu Touch - AirPlay receiver (shairport-sync) Setup
# Installs shairport-sync as an Upstart job and stops PulseAudio from parking
# sink.primary when idle.
#
# Chain: AirPlay -> shairport-sync -> ALSA "pulse" plugin -> PulseAudio
#        sink.primary -> 3.5 mm jack -> stereo.
#
# Runs over SSH (the device is reachable on the LAN). Override the target with
#   PHONE=phablet@<ip> ./setup-shairport.sh

set -e

if [ -f "scripts/config.env" ]; then
    source scripts/config.env
else
    echo "Error: scripts/config.env not found!"
    exit 1
fi

# config.env carries PHONE_HOST so the target address lives in one place
# instead of being repeated (and drifting) across every installer.
PHONE="${PHONE:-phablet@${PHONE_HOST:-192.168.11.9}}"

# Run a command on the phone as root.
as_root() {
    ssh -o BatchMode=yes "$PHONE" "echo $SUDO_PIN | sudo -S -p '' $*"
}

echo "--- Nexus 5 AirPlay Receiver Setup: $DEVICE_NAME ($PHONE) ---"

# 1. Remount system as RW (read-only by default on Ubuntu Touch)
echo "[1/8] Remounting system as Read-Write..."
as_root mount -o remount,rw /

# 2. Install package prerequisites
echo "[2/8] Installing shairport-sync and its backends..."
# shairport-sync 2.8.0 links libpulse-simple, libsoxr and libconfig.
as_root apt-get install -y --no-install-recommends \
    shairport-sync libasound2-plugins libsoxr0 >/dev/null

# 3. Install the application config
echo "[3/8] Installing /etc/shairport-sync.conf..."
scp -q -o BatchMode=yes scripts/shairport-sync.conf "$PHONE:/tmp/shairport-sync.conf"
as_root mv /tmp/shairport-sync.conf /etc/shairport-sync.conf
as_root chown root:root /etc/shairport-sync.conf
as_root chmod 644 /etc/shairport-sync.conf

# 4. Install the Upstart job
echo "[4/8] Installing /etc/init/shairport-sync.conf..."
scp -q -o BatchMode=yes scripts/shairport-sync-service.conf "$PHONE:/tmp/shairport-sync-service.conf"
as_root mv /tmp/shairport-sync-service.conf /etc/init/shairport-sync.conf
as_root chown root:root /etc/init/shairport-sync.conf
as_root chmod 644 /etc/init/shairport-sync.conf

# 5. Let mDNS start at boot
#
# Ubuntu Touch ships /etc/init/avahi-daemon.override containing "manual" -
# "do not start avahi-daemon on boot" - to save power. AirPlay discovery needs
# Avahi, and the shairport-sync job waits on `started avahi-daemon`, so without
# this the receiver never advertises and the job never runs after a reboot.
# Looked like a broken job; was a missing dependency.
#
# Also pins the mDNS hostname to DEVICE_NAME (lowercased), which is the same
# name used by setup.sh, README examples and the home server's
# /etc/music-assistant/hosts sync. Unpinned, Avahi can lose a conflict probe and
# rename itself to <name>-2 on restart, so the SRV record in the AirPlay
# advertisement keeps changing and Music Assistant fails with
# "cliairplay: Cannot resolve hostname". A name nothing else claims stays
# stable.
echo "[5/8] Enabling avahi-daemon at boot..."
{ echo "$SUDO_PIN"; cat <<'AVAHI_EOF'
set -e
name="$1"
f=/etc/init/avahi-daemon.override
if [ -f "$f" ]; then
    cp -n "$f" "$f.pre-receiver"
    rm -f "$f"
    initctl reload-configuration
fi

c=/etc/avahi/avahi-daemon.conf
if ! grep -qx "host-name=$name" "$c"; then
    cp -n "$c" "$c.pre-receiver"
    if grep -qE '^[[:space:]]*host-name=' "$c"; then
        sed -i "s|^[[:space:]]*host-name=.*|host-name=$name|" "$c"
    else
        sed -i "s|^\[server\]|[server]\nhost-name=$name|" "$c"
    fi
    initctl restart avahi-daemon
fi
grep -qx "host-name=$name" "$c" || { echo "host-name pin failed" >&2; exit 1; }
AVAHI_EOF
} | ssh -o BatchMode=yes "$PHONE" "sudo -S -p '' bash -s ${DEVICE_NAME,,}"
as_root initctl start avahi-daemon >/dev/null 2>&1 || true

# 6. Stop PulseAudio parking the sink when idle
#
# PulseAudio parks sink.primary a few seconds after the last stream ends. Every
# new stream then pays a resume cost, and the start of the first AirPlay track
# gets clipped. The startup script that PulseAudio actually reads is patched
# (see step 6), because this project pins default-script-file to touch.pa.
echo "[6/8] Disabling module-suspend-on-idle..."
{ echo "$SUDO_PIN"; cat <<'PULSE_EOF'
set -e
# Patch whichever startup script PulseAudio actually reads. That is NOT
# necessarily /etc/pulse/default.pa: this project's user override in
# ~/.config/pulse/daemon.conf pins default-script-file = /etc/pulse/touch.pa,
# so patching default.pa silently changed nothing and the module came back on
# the next boot.
script=$(cat /home/phablet/.config/pulse/daemon.conf /etc/pulse/daemon.conf 2>/dev/null \
    | grep -m1 '^[[:space:]]*default-script-file' | cut -d= -f2 | tr -d ' ')
[ -n "$script" ] || script=/etc/pulse/default.pa
echo "pulse startup script: $script"
cp -n "$script" "$script.pre-receiver"
sed -i '/^load-module module-suspend-on-idle$/s|^|# Disabled for the AirPlay receiver: suspending sink.primary clips the\n# start of each track.\n#|' "$script"
! grep -q '^load-module module-suspend-on-idle$' "$script"
PULSE_EOF
} | ssh -o BatchMode=yes "$PHONE" "sudo -S -p '' bash -s"
# Take effect immediately too, without restarting PulseAudio, which would cut a
# live session. Unloading does not resume a sink that is already parked, so the
# resume is explicit.
ssh -o BatchMode=yes "$PHONE" \
    'export PULSE_RUNTIME_PATH=/run/user/32011/pulse/; pactl unload-module module-suspend-on-idle 2>/dev/null || true; pactl suspend-sink sink.primary 0 2>/dev/null || true'

# 7. Disable Wi-Fi power save
#
# With power save on, the radio naps between beacons and the receive path
# stutters. The AirPlay bridge can only answer that by truncating the start of a
# track or realigning its timeline mid-stream, and both are audible. Measured
# cause on this device: -36 dBm signal with 0% packet loss, so the jitter was
# power save and not the link.
echo "[7/8] Disabling Wi-Fi power save..."
scp -q -o BatchMode=yes scripts/wifi-powersave.conf "$PHONE:/tmp/wifi-powersave.conf"
as_root mv /tmp/wifi-powersave.conf /etc/init/wifi-powersave.conf
as_root chown root:root /etc/init/wifi-powersave.conf
as_root chmod 644 /etc/init/wifi-powersave.conf
as_root initctl reload-configuration
# Take effect now as well as at the next wlan0 up event.
as_root /sbin/iw dev wlan0 set power_save off

# 8. Replace any hand-started instance with the managed job
echo "[8/8] Starting the shairport-sync job..."
as_root initctl reload-configuration
# -x matches the exact process name: pkill -f would also match this shell,
# because the pattern appears in its own command line.
as_root pkill -x shairport-sync || true
sleep 1
as_root stop shairport-sync 2>/dev/null || true
as_root start shairport-sync

sleep 2
echo
echo "--- Verification ---"
echo -n "process:   "
ssh -o BatchMode=yes "$PHONE" "pgrep -x shairport-sync | head -n 1 || echo 'NOT RUNNING'"
echo -n "advert:    "
ssh -o BatchMode=yes "$PHONE" "avahi-browse -rt _raop._tcp 2>/dev/null | grep -m1 '^=' || echo 'not advertising'"
echo -n "job state: "
as_root status shairport-sync | head -n 1
echo -n "power save: "
ssh -o BatchMode=yes "$PHONE" "iw dev wlan0 get power_save"
echo -n "suspend-on-idle: "
ssh -o BatchMode=yes "$PHONE" \
    'export PULSE_RUNTIME_PATH=/run/user/32011/pulse/; pactl list short modules | grep -c suspend-on-idle'

echo
echo "Done. Pick 'Parlantes' as the AirPlay target, or let Music Assistant find it."
