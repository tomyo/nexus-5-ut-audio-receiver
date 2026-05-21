#!/bin/bash

# Nexus 5 Ubuntu Touch Bluetooth Receiver - Automated Setup
# This script applies all the hacks and scripts developed during the project.

set -e

# Load configuration
if [ -f "scripts/config.env" ]; then
    source scripts/config.env
else
    echo "Error: scripts/config.env not found!"
    exit 1
fi

echo "--- Nexus 5 Bluetooth Receiver Setup: $DEVICE_NAME ---"

# 1. Remount system as RW
echo "[1/6] Remounting system as Read-Write..."
adb shell "echo $SUDO_PIN | sudo -S mount -o remount,rw /"

# 2. Configure Bluetooth for Sink Mode & Speaker Identity
echo "[2/6] Configuring Bluetooth Sink & Identity..."
# Clean up existing entries to prevent duplicates
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Class =/d' /etc/bluetooth/main.conf"
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Enable=/d' /etc/bluetooth/main.conf"
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Name=/d' /etc/bluetooth/main.conf"

# Add fresh entries under [General]
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^\[General\]/a Class = 0x000414' /etc/bluetooth/main.conf"
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^\[General\]/a Enable=Source,Sink,Media,Socket' /etc/bluetooth/main.conf"
adb shell "echo $SUDO_PIN | sudo -S sed -i '/^\[General\]/a Name=$DEVICE_NAME' /etc/bluetooth/main.conf"

# Ensure Avahi (mDNS) is installed and running
echo "Configuring Hostname and mDNS..."
adb shell "echo $SUDO_PIN | sudo -S bash -c 'echo \"PRETTY_HOSTNAME=$DEVICE_NAME\" > /etc/machine-info'"
adb shell "echo $SUDO_PIN | sudo -S bash -c 'echo ${DEVICE_NAME,,} > /etc/hostname'"
adb shell "echo $SUDO_PIN | sudo -S hostname ${DEVICE_NAME,,}"
adb shell "echo $SUDO_PIN | sudo -S sed -i \"s/127.0.1.1.*/127.0.1.1\t${DEVICE_NAME,,}/\" /etc/hosts"

echo "Checking mDNS (Avahi) installation..."
if ! adb shell "which avahi-daemon" > /dev/null; then
    echo "Installing Avahi for .local hostname support..."
    adb shell "echo $SUDO_PIN | sudo -S apt-get update"
    adb shell "echo $SUDO_PIN | sudo -S apt-get install -y avahi-daemon libnss-mdns"
fi
adb shell "echo $SUDO_PIN | sudo -S initctl restart avahi-daemon || echo $SUDO_PIN | sudo -S service avahi-daemon restart || true"

# Ensure SSH is enabled and configured for password login
echo "Configuring SSH for remote access..."
adb shell "echo $SUDO_PIN | sudo -S ssh-keygen -A"
adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config"
adb shell "echo $SUDO_PIN | sudo -S initctl restart ssh || echo $SUDO_PIN | sudo -S service ssh restart || true"

# Force clear adapter cache to ensure the new Class is broadcast
adb shell "echo $SUDO_PIN | sudo -S rm -rf /var/lib/bluetooth/*"

# 3. Optimize PulseAudio & Fix A2DP Crash
echo "[3/6] Tuning PulseAudio engine & fixing stability..."
adb shell "echo $SUDO_PIN | sudo -S sed -i '/resample-method\|default-sample-rate\|default-fragments\|default-fragment-size-msec/d' /etc/pulse/daemon.conf"
adb shell "echo -e 'resample-method = trivial\ndefault-sample-rate = 44100\ndefault-fragments = 10\ndefault-fragment-size-msec = 50' | echo $SUDO_PIN | sudo -S tee -a /etc/pulse/daemon.conf"
# Fix the PulseAudio crash on A2DP connection by removing the forced profile
adb shell "echo $SUDO_PIN | sudo -S sed -i 's/profile=a2dp_sink//' /etc/pulse/touch.pa"

# 4. Deploy background scripts and config
echo "[4/6] Deploying Sync & Auto-Pairing scripts..."
adb push scripts/config.env /home/phablet/config.env
adb push scripts/vol_sync.py /home/phablet/vol_sync.py
adb push scripts/bt_wifi_sync.py /home/phablet/bt_wifi_sync.py
adb push scripts/jack_sense.py /home/phablet/jack_sense.py
adb push scripts/bt_agent.py /home/phablet/bt_agent.py
adb shell "chmod +x /home/phablet/*.py"

# 5. Install System Services
echo "[5/7] Installing persistent background services..."
# Update the Upstart script with the correct governor and UID
sed -i "s/echo .* > /echo $CPU_GOVERNOR > /" scripts/vol-sync.conf
sed -i "s/user\/.*\/pulse/user\/$PA_UID\/pulse/" scripts/vol-sync.conf

for service in vol-sync bt-wifi-sync jack-sense bt-agent; do
    adb push scripts/$service.conf /tmp/$service.conf
    adb shell "echo $SUDO_PIN | sudo -S mv /tmp/$service.conf /etc/init/$service.conf"
    adb shell "echo $SUDO_PIN | sudo -S chown root:root /etc/init/$service.conf"
    adb shell "echo $SUDO_PIN | sudo -S chmod 644 /etc/init/$service.conf"
done

# 6. Configure Screen Timeout, Lockscreen and DT2W
echo "[6/7] Configuring Screen & Wake-on-Touch settings..."
./scripts/adjust-screen-timeout.sh

# 7. Final Info & Reboot
echo "[7/7] Setup complete!"
PHONE_IP=$(adb shell ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
echo "----------------------------------------------------"
echo "Device Hostname: ${DEVICE_NAME,,}.local"
echo "Device IP:       $PHONE_IP"
echo "Remote SSH:      ssh phablet@$PHONE_IP"
echo "----------------------------------------------------"
echo "Rebooting device..."
adb reboot

echo "Done. Once the phone boots, it will be ready as '$DEVICE_NAME'."
