# Bidirectional volume sync: 2026-10-21

## Problem
Volume control from neither device worked:
- Pixel volume changes didn't reach Nexus (MediaTransport.Volume stuck at 127)
- Nexus volume changes didn't reach Pixel (no reverse sync)
- vol_sync.py only synced Bluetooth → PulseAudio, and only on Bluetooth volume change

## Root cause
Android's "Disable absolute volume" (Developer Options) may be ON, or Nexus wasn't advertising AVRCP absolute-volume correctly. MediaTransport.Volume was writable but not monitored for reverse sync.

## Solution
Updated `scripts/vol_sync.py` with bidirectional sync:
- **Bluetooth → Nexus** (existing): On MediaTransport.Volume change, set sink.primary
- **Nexus → Bluetooth** (new): On sink.primary change (not from recent BT sync), write MediaTransport.Volume
- Loop prevention: 1-second cooldown after Bluetooth-initiated sink change

## Verification
```
Nexus 50% → log "Nexus volume 50% -> Bluetooth 63" → MediaTransport 63
MediaTransport 90 → log "Volumes synced to 70%" → sink 70%
```

## Deployment
- Replaced /home/phablet/vol_sync.py
- Restarted vol-sync Upstart service
- Previous script backed up at /home/phablet/audio-quality-backup/vol_sync.before-buffer.py

## Rollback
Restore /home/phablet/audio-quality-backup/vol_sync.before-buffer.py to /home/phablet/vol_sync.py, restart vol-sync.

## Note
Pixel hardware volume buttons should now control Nexus output. If not, check Pixel Developer Options → "Disable absolute volume" (should be OFF).