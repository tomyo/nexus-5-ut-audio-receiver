#!/bin/bash

# Script to configure screen timeout and wake settings on Ubuntu Touch
# Usage: ./scripts/adjust-screen-timeout.sh

# Load configuration
if [ -f "scripts/config.env" ]; then
    source scripts/config.env
else
    echo "Error: scripts/config.env not found!"
    exit 1
fi

# Get current DBUS session address for the phablet user
# Try both unity8 and lomiri, and strip carriage returns
SHELL_PID=$(adb shell "pidof unity8 || pidof lomiri" | tr -d '\r' | awk '{print $1}')
RAW_ADDR=$(adb shell "echo $SUDO_PIN | sudo -S cat /proc/$SHELL_PID/environ | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-")

# Clean the output (strip sudo prompt, newlines, and carriage returns)
DBUS_ADDR=$(echo "$RAW_ADDR" | sed "s/\[sudo\] password for phablet: //g" | tr -d '\r\n')

if [ -z "$DBUS_ADDR" ]; then
    echo "Error: Could not find Shell DBUS session address."
    exit 1
fi

echo "Using DBUS Address: $DBUS_ADDR"

# 1. Set timeout to 1 minute (60 seconds)
echo "Setting screen timeout to 60 seconds..."
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set com.ubuntu.touch.system activity-timeout 60"

# 2. Disable lockscreen (GNOME/Ubuntu specific keys found on device)
echo "Disabling lockscreen..."
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver lock-enabled false"
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend false"
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver idle-activation-enabled false"
adb shell "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR gsettings set org.gnome.desktop.screensaver lock-delay 0"

# 3. Enable Double Tap to Wake (Hardware node for Nexus 5)
echo "Enabling Double Tap to Wake (if supported by kernel)..."
adb shell "echo $SUDO_PIN | sudo -S bash -c 'echo 1 > /sys/bus/i2c/devices/1-004a/double_tap'" || true
adb shell "echo $SUDO_PIN | sudo -S bash -c 'echo 1 > /sys/android_touch/doubletap2wake'" || true

echo "Settings applied successfully."
