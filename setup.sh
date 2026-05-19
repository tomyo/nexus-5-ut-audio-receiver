#!/bin/bash

# Nexus 5 Ubuntu Touch Bluetooth Receiver - Automated Setup
# This script applies all the hacks and scripts developed during the project.

set -e

echo "--- Nexus 5 Bluetooth Receiver Setup ---"

# 1. Remount system as RW
echo "[1/6] Remounting system as Read-Write..."
adb shell "echo 1234 | sudo -S mount -o remount,rw /"

# 2. Configure Bluetooth for Sink Mode & Speaker Identity
echo "[2/6] Configuring Bluetooth Sink & Identity..."
adb shell "echo 1234 | sudo -S sed -i 's/^Class =.*/Class = 0x000414/' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S sed -i '/^\[General\]/a Class = 0x000414' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S sed -i '/^Enable=/d' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S sed -i '/^\[General\]/a Enable=Source,Sink,Media,Socket' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S sed -i '/^Name=/d' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S sed -i '/^\[General\]/a Name=Parlantes' /etc/bluetooth/main.conf"
adb shell "echo 1234 | sudo -S bash -c 'echo \"PRETTY_HOSTNAME=Parlantes\" > /etc/machine-info'"
adb shell "echo 1234 | sudo -S sed -i 's/127.0.1.1.*/127.0.1.1\tParlantes/' /etc/hosts"
# Force clear adapter cache to ensure the new Class is broadcast
adb shell "echo 1234 | sudo -S rm -rf /var/lib/bluetooth/*"

# 3. Optimize PulseAudio & Fix A2DP Crash
echo "[3/6] Tuning PulseAudio engine & fixing stability..."
adb shell "echo 1234 | sudo -S sed -i '/resample-method\|default-sample-rate\|default-fragments\|default-fragment-size-msec/d' /etc/pulse/daemon.conf"
adb shell "echo -e 'resample-method = trivial\ndefault-sample-rate = 44100\ndefault-fragments = 10\ndefault-fragment-size-msec = 50' | echo 1234 | sudo -S tee -a /etc/pulse/daemon.conf"
# Fix the PulseAudio crash on A2DP connection by removing the forced profile
adb shell "echo 1234 | sudo -S sed -i 's/profile=a2dp_sink//' /etc/pulse/touch.pa"

# 4. Deploy background scripts
echo "[4/6] Deploying Sync & Auto-Pairing scripts..."
adb push scripts/vol_sync.py /home/phablet/vol_sync.py
adb push scripts/bt_agent.py /home/phablet/bt_agent.py
adb shell "chmod +x /home/phablet/vol_sync.py /home/phablet/bt_agent.py"

# 5. Install System Services
echo "[5/7] Installing persistent background services..."
adb push scripts/vol-sync.conf /tmp/vol-sync.conf
adb shell "echo 1234 | sudo -S mv /tmp/vol-sync.conf /etc/init/vol-sync.conf"
adb push scripts/bt-agent.conf /tmp/bt-agent.conf
adb shell "echo 1234 | sudo -S mv /tmp/bt-agent.conf /etc/init/bt-agent.conf"
adb shell "echo 1234 | sudo -S chown root:root /etc/init/vol-sync.conf /etc/init/bt-agent.conf"
adb shell "echo 1234 | sudo -S chmod 644 /etc/init/vol-sync.conf /etc/init/bt-agent.conf"

# 6. Configure Screen Timeout, Lockscreen and DT2W
echo "[6/7] Configuring Screen & Wake-on-Touch settings..."
./scripts/adjust-screen-timeout.sh

# 7. Reboot
echo "[7/7] Setup complete! Rebooting device..."
adb reboot

echo "Done. Once the phone boots, it will be ready as 'Parlantes' with Volume Sync active."
