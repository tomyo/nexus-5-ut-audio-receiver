# Loopback fix: 2026-10-21

## Problem
Mic audio was routing to speakers when no Bluetooth music was playing, and a phaser/flanger effect occurred during playback.

## Root cause
1. `module-loopback` was created with `source=bluez_source.94_45_60_BE_43_80` before the Bluetooth A2DP source existed (Pixel not streaming). When the specified source is missing, PulseAudio falls back to the **default source** — the built-in microphone.
2. When Pixel started streaming, `module-bluetooth-policy` created its **own default loopback** for the same Bluetooth device (using `source=bluez_source.94_45_60_BE_43_80.2` monitor). Two loopbacks playing the same audio with slight timing differences → comb filter (phaser/flanger).

## Solution
Updated `scripts/vol_sync.py`:
- `get_bt_a2dp_source()`: Only returns Bluetooth source if it **exists AND is RUNNING** (parses `pactl list sources` for State: RUNNING).
- `ensure_loopback()`: Now matches loopbacks by **base device name** (e.g., `bluez_source.94_45_60_BE_43_80`), so it unloads policy-created variants (`.2`, etc.) and only keeps our `latency_msec=200` loopback.
- Only creates loopback when active Bluetooth A2DP source exists.

## Verification
- Mic→speaker routing eliminated when Bluetooth idle.
- Single loopback confirmed (`latency_msec=200` only).
- Phaser/flanger effect eliminated.
- Bidirectional volume sync still works.

## Deployment
- Replaced /home/phablet/vol_sync.py, restarted vol-sync.
- Previous script backed up at /home/phablet/audio-quality-backup/vol_sync.before-buffer.py.

## Rollback
Restore backup, restart vol-sync.