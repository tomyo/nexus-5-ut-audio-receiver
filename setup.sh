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

REBOOT_REQUIRED=0
IS_RW=0

confirm() {
    local prompt="$1"
    read -p "$prompt [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_rw() {
    if [ $IS_RW -eq 0 ]; then
        echo "Remounting system as Read-Write..."
        adb shell "echo $SUDO_PIN | sudo -S mount -o remount,rw /"
        IS_RW=1
    fi
}

echo "--- Nexus 5 Bluetooth Receiver Setup: $DEVICE_NAME ---"

# 1. Configure Bluetooth for Sink Mode & Speaker Identity
if confirm "[1/6] Configure Bluetooth Identity (Name, Class, mDNS, SSH)?"; then
    ensure_rw
    echo "Configuring Bluetooth Sink & Identity..."
    # Preserve saved pairings; identity changes do not justify deleting bonds.
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Class[[:space:]]*=/d' /etc/bluetooth/main.conf"
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Enable=/d' /etc/bluetooth/main.conf"
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/^Name=/d' /etc/bluetooth/main.conf"

    # Add fresh entries under [General]
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/^\[General\]/a Class = 0x000414' /etc/bluetooth/main.conf"
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/^\[General\]/a Name=$DEVICE_NAME' /etc/bluetooth/main.conf"

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
    echo "Ensuring mDNS is prioritized in nsswitch.conf..."
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^hosts:.*/hosts: files mdns_minimal [NOTFOUND=return] dns /' /etc/nsswitch.conf"

    echo "Configuring SSH for remote access..."
    adb shell "echo $SUDO_PIN | sudo -S ssh-keygen -A"
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config"
    adb shell "echo $SUDO_PIN | sudo -S initctl restart ssh || echo $SUDO_PIN | sudo -S service ssh restart || true"

    REBOOT_REQUIRED=1
fi

# 2. Optimize PulseAudio & Fix A2DP Crash
if confirm "[2/6] Optimize PulseAudio engine & fix A2DP stability?"; then
    ensure_rw
    echo "Tuning PulseAudio engine & fixing stability..."
    adb shell "echo $SUDO_PIN | sudo -S sed -i '/resample-method\|default-sample-rate\|default-fragments\|default-fragment-size-msec/d' /etc/pulse/daemon.conf"
    adb shell "echo $SUDO_PIN | sudo -S bash -c \"echo -e 'resample-method = speex-fixed-4\ndefault-sample-rate = 44100\ndefault-fragments = 10\ndefault-fragment-size-msec = 50' >> /etc/pulse/daemon.conf\""
    adb shell "mkdir -p /home/phablet/.config/pulse"
    adb push scripts/receiver-daemon.conf /home/phablet/.config/pulse/daemon.conf
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^load-module module-udev-detect$/load-module module-udev-detect tsched=0/' /etc/pulse/default.pa"
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/^load-module module-udev-detect$/load-module module-udev-detect tsched=0/' /etc/pulse/system.pa"
    # Fix the PulseAudio crash on A2DP connection by removing the forced profile
    adb shell "echo $SUDO_PIN | sudo -S sed -i 's/profile=a2dp_sink//; s/^load-module module-bluetooth-policy .*/load-module module-bluetooth-policy/' /etc/pulse/touch.pa"
    REBOOT_REQUIRED=1
fi

# 3. Deploy background scripts and config
if confirm "[3/6] Deploy background Python scripts (Sync, WiFi toggle, etc.)?"; then
    # No RW needed as /home is usually RW
    echo "Deploying Sync & Auto-Pairing scripts..."
    adb shell "python3 -c 'import dbus; from gi.repository import GLib'"
    adb push scripts/config.env /home/phablet/config.env
    adb push scripts/vol_sync.py /home/phablet/vol_sync.py
    adb push scripts/bt_wifi_sync.py /home/phablet/bt_wifi_sync.py
    adb push scripts/jack_sense.py /home/phablet/jack_sense.py
    adb push scripts/bt_agent.py /home/phablet/bt_agent.py
    adb push scripts/keep_awake.py /home/phablet/keep_awake.py
    adb shell "chmod +x /home/phablet/*.py"
fi

# 4. Install System Services
if confirm "[4/6] Install and start persistent background services?"; then
    ensure_rw
    echo "Installing persistent background services..."
    # Render device settings without modifying repository templates.
    SERVICE_TMP=$(mktemp -d)
    trap 'rm -rf "$SERVICE_TMP"' EXIT
    for service in vol-sync bt-wifi-sync jack-sense bt-agent keep-awake; do
        sed -e "s/echo performance > /echo $CPU_GOVERNOR > /" \
            -e "s@/run/user/32011/@/run/user/$PA_UID/@g" \
            "scripts/$service.conf" > "$SERVICE_TMP/$service.conf"
        adb push "$SERVICE_TMP/$service.conf" /tmp/$service.conf
        adb shell "echo $SUDO_PIN | sudo -S mv /tmp/$service.conf /etc/init/$service.conf"
        adb shell "echo $SUDO_PIN | sudo -S chown root:root /etc/init/$service.conf"
        adb shell "echo $SUDO_PIN | sudo -S chmod 644 /etc/init/$service.conf"
        adb shell "echo $SUDO_PIN | sudo -S initctl stop $service || true"
        adb shell "echo $SUDO_PIN | sudo -S initctl start $service || true"
    done
fi

# 5. Configure Screen Timeout, Lockscreen and DT2W
if confirm "[5/6] Apply Screen Timeout and Lockscreen settings?"; then
    # No RW needed for gsettings or /sys
    echo "Configuring Screen & Wake-on-Touch settings..."
    ./scripts/adjust-screen-timeout.sh
fi

# 6. Create Rescue Admin User (To remove lockscreen)
if confirm "[6/6] Create 'rescueadmin' user to allow safely removing the PIN/lockscreen?"; then
    ensure_rw
    echo "Creating rescueadmin user; set its password interactively on the phone."
    # If the user doesn't exist, create it
    if ! adb shell "id rescueadmin" > /dev/null 2>&1; then
        adb shell "echo $SUDO_PIN | sudo -S useradd -m -s /bin/bash rescueadmin"
        adb shell "echo $SUDO_PIN | sudo -S usermod -aG sudo rescueadmin"

        echo "Created locked rescueadmin account. Run sudo passwd rescueadmin on the phone"
        echo "and verify login before changing the lockscreen. No default password is installed."
    else
        echo "User rescueadmin already exists."
    fi
fi

echo "--- Setup complete! ---"
PHONE_IP=$(adb shell ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
echo "Device Hostname: ${DEVICE_NAME,,}.local"
echo "Device IP:       $PHONE_IP"
echo "Remote SSH:      ssh phablet@$PHONE_IP"
echo "----------------------------------------------------"

if [ $REBOOT_REQUIRED -eq 1 ]; then
    if confirm "Changes were made that require a reboot. Reboot now?"; then
        echo "Rebooting device..."
        adb reboot
        echo "Done. Once the phone boots, it will be ready."
    else
        echo "Please remember to reboot the device later to apply all changes."
    fi
else
    echo "No reboot required. All changes applied live."
fi
