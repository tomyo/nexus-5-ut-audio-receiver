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

PHONE="${PHONE:-phablet@192.168.11.197}"

if [ -f "scripts/config.env" ]; then
    source scripts/config.env
else
    echo "Error: scripts/config.env not found!"
    exit 1
fi

# Run a command on the phone as root.
as_root() {
    ssh -o BatchMode=yes "$PHONE" "echo $SUDO_PIN | sudo -S -p '' $*"
}

echo "--- Nexus 5 AirPlay Receiver Setup: $DEVICE_NAME ($PHONE) ---"

# 1. Remount system as RW (read-only by default on Ubuntu Touch)
echo "[1/6] Remounting system as Read-Write..."
as_root mount -o remount,rw /

# 2. Install package prerequisites
echo "[2/6] Installing shairport-sync and its backends..."
# shairport-sync 2.8.0 links libpulse-simple, libsoxr and libconfig.
as_root apt-get install -y --no-install-recommends \
    shairport-sync libasound2-plugins libsoxr0 >/dev/null

# 3. Install the application config
echo "[3/6] Installing /etc/shairport-sync.conf..."
scp -q -o BatchMode=yes scripts/shairport-sync.conf "$PHONE:/tmp/shairport-sync.conf"
as_root mv /tmp/shairport-sync.conf /etc/shairport-sync.conf
as_root chown root:root /etc/shairport-sync.conf
as_root chmod 644 /etc/shairport-sync.conf

# 4. Install the Upstart job
echo "[4/6] Installing /etc/init/shairport-sync.conf..."
scp -q -o BatchMode=yes scripts/shairport-sync-service.conf "$PHONE:/tmp/shairport-sync-service.conf"
as_root mv /tmp/shairport-sync-service.conf /etc/init/shairport-sync.conf
as_root chown root:root /etc/init/shairport-sync.conf
as_root chmod 644 /etc/init/shairport-sync.conf

# 5. Stop PulseAudio parking the sink when idle
#
# PulseAudio parks sink.primary a few seconds after the last stream ends. Every
# new stream then pays a resume cost, and the start of the first AirPlay track
# gets clipped. /etc/pulse/default.pa is patched directly rather than shadowed
# by a per-user default.pa: a broken include there would leave the phone with no
# audio at all, which is a far worse failure than a clipped note.
echo "[5/6] Disabling module-suspend-on-idle..."
{ echo "$SUDO_PIN"; cat <<'PULSE_EOF'
set -e
f=/etc/pulse/default.pa
cp -n "$f" "$f.pre-receiver"
# Address the active load line only, so re-running cannot nest comments.
sed -i '/^load-module module-suspend-on-idle$/s|^|# Disabled for the AirPlay receiver: suspending sink.primary clips the\n# start of each track.\n#|' "$f"
# Assert the invariant, not the exact comment wording, so a differently worded
# patch still counts as done.
! grep -q '^load-module module-suspend-on-idle$' "$f"
PULSE_EOF
} | ssh -o BatchMode=yes "$PHONE" "sudo -S -p '' bash -s"
# Take effect immediately too, without restarting PulseAudio, which would cut a
# live session: the module can also be unloaded at runtime.
ssh -o BatchMode=yes "$PHONE" \
    'PULSE_RUNTIME_PATH=/run/user/32011/pulse/ pactl unload-module module-suspend-on-idle 2>/dev/null || true'

# 6. Replace any hand-started instance with the managed job
echo "[6/6] Starting the shairport-sync job..."
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

echo
echo "Done. Pick 'Parlantes' as the AirPlay target, or let Music Assistant find it."
