#!/bin/bash

# Remove the retired Spotify Connect daemon (go-librespot) from the phone.
#
# Idempotent: safe to run repeatedly, and safe on a device that never had it.
# Run this after a factory reset or a replay of setup.sh to assert the retired
# state, instead of remembering the file list by hand.
#
# What it removes:
#   /etc/init/spotifyd.conf, /etc/init/spotifyd.override   (the Upstart job)
#   /usr/bin/go-librespot{,.bak}, /usr/bin/spotifyd.v*.bak (the binaries)
#   ~/.config/go-librespot/                                (device identity)
#   ~/spotify-backup-before-v0.10.5/                       (upgrade backup)
#
# Why it is retired: Music Assistant on the home server plays Spotify via
# Spotify's own Soloist engine, and these reverse-engineered clients cannot play
# at all ("error audio key 0 1"). go-librespot also published parlantes.local
# through its own Zeroconf library, which collided with avahi-daemon and made
# Music Assistant fail with "cliairplay: Cannot resolve hostname".

set -e

# Load configuration
if [ -f "scripts/config.env" ]; then
    # shellcheck disable=SC1091
    source scripts/config.env
else
    echo "Error: scripts/config.env not found! Run this from the repository root." >&2
    exit 1
fi

PHONE="${PHONE:-phablet@${PHONE_HOST:-192.168.11.9}}"

echo "--- Retiring the Spotify Connect daemon on $DEVICE_NAME ($PHONE) ---"

{ echo "$SUDO_PIN"; cat <<'RETIRE_EOF'
set -e

before=$(df -k / | awk 'NR==2 {print $4}')

# The system partition is mounted read-only on Ubuntu Touch.
mount -o remount,rw /

initctl stop spotifyd 2>/dev/null || true

rm -f /etc/init/spotifyd.conf \
      /etc/init/spotifyd.override \
      /usr/bin/go-librespot /usr/bin/go-librespot.bak \
      /usr/bin/spotifyd.v0.2.24.bak /usr/bin/spotifyd.v0.4.2.bak

rm -rf /home/phablet/.config/go-librespot \
       /home/phablet/spotify-backup-before-v0.10.5

initctl reload-configuration

# Put the root filesystem back the way Ubuntu Touch wants it.
mount -o remount,ro /

after=$(df -k / | awk 'NR==2 {print $4}')
echo "freed_kb=$((after - before))"

echo "--- state ---"
echo -n "job:      "; initctl status spotifyd 2>&1 | head -n 1
echo -n "binaries: "; ls /usr/bin/go-librespot /usr/bin/spotifyd.v0.2.24.bak 2>/dev/null | wc -l
echo -n "config:   "; [ -d /home/phablet/.config/go-librespot ] && echo present || echo absent
echo -n "root fs:  "; mount | grep -m1 ' / ' | sed 's/.*(\(.*\))/\1/'
RETIRE_EOF
} | ssh -o BatchMode=yes "$PHONE" "sudo -S -p '' bash -s"

echo "--- verification ---"
echo -n "spotify-connect adverts: "
ssh -o BatchMode=yes "$PHONE" 'timeout 6 avahi-browse -t _spotify-connect._tcp 2>/dev/null | grep -c "^=" || true'

echo -n "AirPlay still advertising: "
ssh -o BatchMode=yes "$PHONE" "avahi-browse -rt _raop._tcp 2>/dev/null | grep -m1 '^=' || echo 'NOT ADVERTISING'"

echo "Done. The phone now advertises only as an AirPlay receiver."
