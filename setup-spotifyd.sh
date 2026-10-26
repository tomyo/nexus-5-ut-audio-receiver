#!/bin/bash

# Nexus 5 Ubuntu Touch - Spotify Connect (via go-librespot) Setup
# This script installs and configures go-librespot as a background service.

set -e

# Load configuration
if [ -f "scripts/config.env" ]; then
    source scripts/config.env
else
    echo "Error: scripts/config.env not found!"
    exit 1
fi

# RETIRED. Do not run this. Music Assistant on the home server now plays
# Spotify itself using Spotify's own Soloist engine, and the phone's only job is
# to be an AirPlay receiver.
#
# The clients this script installs cannot play at all: Spotify refuses the audio
# key ("error audio key 0 1"), and go-librespot additionally published
# parlantes.local through its own Zeroconf library, which collided with
# avahi-daemon on this device and made Music Assistant fail with
# "cliairplay: Cannot resolve hostname". See diagnostics/spotify-audio-key-root-cause.md
# and the Spotify section of README.md.
#
# Kept for reference only. To reinstall the broken client deliberately (to
# reproduce the failure), run: bash setup-spotifyd.sh --force
if [ "${1:-}" != "--force" ]; then
    cat <<'MSG'
Refusing to run: this installer is retired.

Spotify playback is handled by Music Assistant on home-zotac-01. Nothing from
this script is installed on the phone, and the phone's go-librespot, its config
and its Upstart job were deliberately removed.

Use scripts/retire-spotifyd.sh to assert that state (idempotent), and
scripts/verify-receiver.sh to check the AirPlay receiver.

Re-run with --force to install the broken client for reproduction only.
MSG
    exit 1
fi

echo "--- Nexus 5 Spotify Connect Setup: $DEVICE_NAME ---"

# 1. Remount system as RW
echo "[1/4] Remounting system as Read-Write..."
adb shell "echo $SUDO_PIN | sudo -S mount -o remount,rw /"

# 2. Install System Service
echo "[2/4] Installing Upstart service..."
adb push scripts/go-librespot-service.conf /tmp/spotifyd.conf
adb shell "echo $SUDO_PIN | sudo -S mv /tmp/spotifyd.conf /etc/init/spotifyd.conf"
adb shell "echo $SUDO_PIN | sudo -S chown root:root /etc/init/spotifyd.conf"
adb shell "echo $SUDO_PIN | sudo -S chmod 644 /etc/init/spotifyd.conf"

# 3. Install go-librespot binary and config
echo "[3/4] Deploying go-librespot binary and configuration..."
# Update go-librespot.yml with config values
sed -i "s/device_name: .*/device_name: \"$DEVICE_NAME\"/" scripts/go-librespot.yml
sed -i "s/bitrate: .*/bitrate: $BITRATE/" scripts/go-librespot.yml
if [ ! -f "go-librespot" ]; then
    echo "go-librespot binary not found locally. Downloading v0.10.5 for armv6..."
    wget -O go-librespot.tar.gz https://github.com/devgianlu/go-librespot/releases/download/v0.10.5/go-librespot_linux_armv6.tar.gz
    tar -xzf go-librespot.tar.gz
fi
adb push go-librespot /tmp/go-librespot
adb shell "echo 1234 | sudo -S mv /tmp/go-librespot /usr/bin/go-librespot"
adb shell "echo 1234 | sudo -S chmod +x /usr/bin/go-librespot"

adb shell "mkdir -p /home/phablet/.config/go-librespot"
adb push scripts/go-librespot.yml /home/phablet/.config/go-librespot/config.yml
adb shell "chown -R phablet:phablet /home/phablet/.config/go-librespot"

# 4. Start Service
echo "[4/4] Starting service..."
# Stop old spotifyd service if it was running (though it likely failed)
adb shell "echo $SUDO_PIN | sudo -S stop spotifyd || true"
adb shell "echo $SUDO_PIN | sudo -S start spotifyd"

echo "Done. '$DEVICE_NAME' should now appear in your Spotify Connect devices."
