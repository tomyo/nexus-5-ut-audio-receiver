# Nexus 5 Ubuntu Touch Bluetooth Audio Receiver

This project converts a legacy LG Nexus 5 (hammerhead) into a high-quality, dedicated Bluetooth A2DP Sink (receiver) and Spotify Connect endpoint using Ubuntu Touch.

## Goal
Transform the device into a "headless" Bluetooth and Spotify bridge for a stereo system, supporting:
- Automatic pairing (No-PIN acceptance).
- Universal remote volume synchronization (Absolute Volume).
- Automatic audio routing between internal speakers and the 3.5mm jack.
- Spotify Connect support via `go-librespot`.
- High-stability audio with zero stuttering/choppiness.

## Project Structure
- `scripts/vol_sync.py`: Background service for volume, jack synchronization, and A2DP loopback monitoring.
- `scripts/bt_agent.py`: Bluetooth agent for auto-accepting pairings and maintaining discoverability.
- `scripts/vol-sync.conf`: Upstart service configuration for volume and jack sync.
- `scripts/bt-agent.conf`: Upstart service configuration for the auto-pairing agent.
- `scripts/go-librespot.yml`: Spotify Connect configuration (for go-librespot).
- `scripts/go-librespot-service.conf`: Spotify Connect Upstart service configuration.
- `setup.sh`: Automated installer script for fresh Ubuntu Touch installations.
- `setup-spotifyd.sh`: Independent installer script for Spotify Connect support.

## Technical Findings & Stability Fixes

### Bluetooth "Phone" vs "Speaker" Identity
The Nexus 5 hardware/firmware often forces a "Smartphone" Class of Device (CoD). Even when `main.conf` is updated, BlueZ sticks to its cached identity in `/var/lib/bluetooth`.
- **Fix:** We force the CoD to `0x000414` (Audio/Video, Loudspeaker) and clear the `/var/lib/bluetooth` cache during setup to force a broadcast of the new identity.

### PulseAudio A2DP Connection Crash
A race condition in Ubuntu Touch's PulseAudio causes an assertion failure when forcing `profile=a2dp_sink` during device discovery.
- **Fix:** We removed the forced profile from `/etc/pulse/touch.pa` and moved the profile switching logic to our custom `vol_sync.py` script, which applies the profile only after the connection is stable.

### Silent Audio Drops
PulseAudio's policy manager often mutes or removes "Loopback" streams used for Bluetooth audio.
- **Fix:** The `vol_sync.py` script now aggressively monitors the loopback bridge and automatically recreates/unmutes it if it drops, ensuring "indestructible" audio playback.

### GLIBC Compatibility (Spotify)
Modern `spotifyd` and `librespot` binaries require GLIBC 2.27+, but Ubuntu Touch 16.04 only provides GLIBC 2.23.
- **Fix:** Used `go-librespot` (Go-based) with an `armv6` Linux binary, which is statically linked enough to run on older GLIBC versions without issues.

## Requirements
- LG Nexus 5 (hammerhead)
- Ubuntu Touch (Installed via UBports Installer)
- Developer Mode enabled on the device.
- Standard 3.5mm stereo cable.

## Installation (Fresh Setup)
1. Connect the phone to your computer via USB.
2. Run the `setup.sh` script for Bluetooth/System basics.
3. Run the `setup-spotifyd.sh` script for Spotify Connect support.
4. The phone will reboot and be ready to use as "Parlantes".

## Usage
1. Power on the phone.
2. Search for Bluetooth devices on your computer or smartphone.
3. Connect to **"Parlantes"**.
4. Alternatively, find **"Parlantes"** in your Spotify app under "Devices".
