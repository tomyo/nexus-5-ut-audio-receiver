#!/bin/bash

# Script to configure screen timeout and wake settings on Ubuntu Touch
# Usage: ./scripts/adjust-screen-timeout.sh

# Get current DBUS session address for the phablet user
# We use sudo to read the environment of the unity8 process
RAW_ADDR=$(adb shell "echo 1234 | sudo -S cat /proc/\$(pidof unity8)/environ | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-")

# Clean the output (strip sudo prompt and newlines)
DBUS_ADDR=$(echo "$RAW_ADDR" | sed 's/\[sudo\] password for phablet: //g' | tr -d '\r\n')

if [ -z "$DBUS_ADDR" ]; then
    echo "Error: Could not find Unity8 DBUS session address."
    exit 1
fi

echo "Using DBUS Address: $DBUS_ADDR"

# 1. Set timeout to 1 minute (60 seconds)
echo "Setting screen timeout to 60 seconds..."
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set com.ubuntu.touch.system activity-timeout 60"

# 2. Disable lockscreen
echo "Disabling lockscreen..."
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver lock-enabled false"
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver idle-activation-enabled true"

# 3. Enable Double Tap to Wake (Hardware node for Nexus 5)
echo "Enabling Double Tap to Wake (if supported by kernel)..."
adb shell "echo 1234 | sudo -S bash -c 'echo 1 > /sys/bus/i2c/devices/1-004a/double_tap'" || true
adb shell "echo 1234 | sudo -S bash -c 'echo 1 > /sys/android_touch/doubletap2wake'" || true

echo "Settings applied successfully."
