# Stable receiver cleanup

## Retained contract

PulseAudio's built-in Bluetooth policy owns the incoming A2DP bridge and profile. The volume service only maps a single active sender's Volume to sink.primary. The user confirmed playback and Pixel volume buttons after the volume-only recovery. There is no custom bridge recovery, reverse volume sync, or explicit 200 ms buffer. Add a measured, reversible buffer trial only if chopping returns and the user requests it.

The installer now reproduces the speex-fixed-4 user override and Touch startup selection, preserves Bluetooth bonds, and renders service templates in temporary files. Bluetooth helpers start with system D-Bus rather than Wi-Fi and no longer stop with the Unity shell. These event changes are installed but not reboot-tested.

Supporting scripts were inspected in full: bt_agent.py, bt_wifi_sync.py, jack_sense.py, keep_awake.py and vol_sync.py, plus service templates. Pairing and power features remain. Wi-Fi detection now uses typed D-Bus objects and checks all incoming transports; it no longer overwrites resolv.conf, remounts root, or restarts the obsolete spotifyd service. Jack detection uses actual named output ports and retries failed switches. Automatic pairing is permissive and authorizes services: retain only in a trusted physical environment. Power wakelocks can increase heat and consumption.

## Verification performed

- Local tests cover volume changes, bounds, idle/ambiguous senders, pause/resume, reconnection, failed writes, radio state, named jack ports, installer invariants, service events, and Python syntax.
- Phone Python is 3.5.2; deployed scripts parsed successfully with that interpreter.
- SHA-256 hashes matched repository/deployed vol_sync.py, bt_wifi_sync.py, jack_sense.py and keep_awake.py.
- Installed five service templates and restarted only vol-sync, jack-sense and bt-wifi-sync successfully. Jack helper reported output-speaker with physical jack state 0. No Bluetooth source/bridge existed at this inspection: it is not a playback verification.
- PulseAudio policy remained loaded; the resampler override already matched scripts/receiver-daemon.conf. PulseAudio itself was not restarted and the full installer was not executed.
- Backups of replaced scripts/service files: /home/phablet/audio-quality-backup/stable-cleanup/. Do not restore the earlier faulty volume watchdog.
- Subsequent ADB checks returned `adb: no devices/emulators found`. No live reconnect/reboot claim is justified.

## Required device follow-up

1. Reconnect USB, insert the audio cable, connect Pixel Bluetooth, and play music. Confirm exactly one Bluetooth-to-output bridge, correct jack port and no microphone loopback.
2. Change Pixel volume; pause/resume, then disconnect/reconnect. Confirm audio and volume return, and Wi-Fi is off only while incoming playback is active.
3. When an interruption is acceptable, reboot. Confirm all five helpers start without needing Wi-Fi association, then repeat playback and volume checks. Check speaker/jack transitions too.
4. Listen for chopping. Leave buffer defaults alone unless the symptom returns. Spotify, fresh installation, mDNS, and lockscreen/security changes need separate verification.

## Repository boundaries

Existing related setup/README additions are retained in the cleanup (including deployment of the previously untracked keep_awake.py). Pre-existing edits to scripts/adjust-screen-timeout.sh and untracked NO_LOCKSCREEN.md/test_power.sh are not committed as part of this task. No credentials are changed. Historical diagnostics have explicit superseded notices; older logs are evidence, not current instructions.
