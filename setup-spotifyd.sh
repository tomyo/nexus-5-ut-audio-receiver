#!/bin/bash

# Nexus 5 Ubuntu Touch - Spotify Connect (via go-librespot) Setup
# This script installs and configures go-librespot as a background service.

set -e

echo "--- Nexus 5 Spotify Connect Setup ---"

# 1. Remount system as RW
echo "[1/4] Remounting system as Read-Write..."
adb shell "echo 1234 | sudo -S mount -o remount,rw /"

# 2. Install System Service
echo "[2/4] Installing Upstart service..."
adb push scripts/go-librespot-service.conf /tmp/spotifyd.conf
adb shell "echo 1234 | sudo -S mv /tmp/spotifyd.conf /etc/init/spotifyd.conf"
adb shell "echo 1234 | sudo -S chown root:root /etc/init/spotifyd.conf"
adb shell "echo 1234 | sudo -S chmod 644 /etc/init/spotifyd.conf"

# 3. Install go-librespot binary and config
echo "[3/4] Deploying go-librespot binary and configuration..."
if [ ! -f "go-librespot" ]; then
    echo "go-librespot binary not found locally. Downloading v0.7.1 for armv6..."
    wget -O go-librespot.tar.gz https://github.com/devgianlu/go-librespot/releases/download/v0.7.1/go-librespot_linux_armv6.tar.gz
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
adb shell "echo 1234 | sudo -S stop spotifyd || true"
adb shell "echo 1234 | sudo -S start spotifyd"

echo "Done. 'Parlantes' should now appear in your Spotify Connect devices."
