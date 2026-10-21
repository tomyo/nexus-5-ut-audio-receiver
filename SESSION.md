# Project State: Nexus 5 Bluetooth Audio Receiver

## Objective
Convert a Nexus 5 (hammerhead) into a dedicated, high-quality Bluetooth audio receiver for a stereo system.

## Current Configuration
- **Operating System:** Ubuntu Touch (Linux-based, installed via UBports).
- **Partition Layout:** Reset to Stock 16GB (Fixed "No space left on device" errors in installer).
- **Audio Stack:** PulseAudio 8.0.
- **Bluetooth Stack:** BlueZ 5.41.
- **System Modifications:**
    - `/etc/bluetooth/main.conf`: Enabled `Source,Sink,Media,Socket`. Set `Name=Parlantes` and `Class=0x200414` (Loudspeaker).
    - `/etc/pulse/daemon.conf`: System baseline remains `resample-method=trivial`, `default-sample-rate=44100`, and fragments `10` x `50ms`. Realtime scheduling is commented out, not explicitly enabled in this file.
    - `/home/phablet/.config/pulse/daemon.conf`: Accepted user override includes the system config, sets `resample-method = speex-fixed-4`, and explicitly selects `default-script-file = /etc/pulse/touch.pa`. This is the effective quality setting; setup scripts have NOT been updated to reproduce it.
    - `/etc/init/vol-sync.conf`: Custom persistent Upstart service that manages:
        - CPU Governor (set to `performance`).
        - WiFi Radio (disabled to prevent 2.4GHz interference).
        - PulseAudio environment permissions.
        - Execution of `vol_sync.py` and `bt_agent.py`.

## Current Status
- **Identity:** Bluetooth name **Parlantes**, hostname `parlantes`. Latest controller inspection still reported Smartphone class `0x1c020c`; historical speaker-identity fixes are not proof of the live class.
- **Audio Quality:** User accepted `speex-fixed-4` after a three-minute monitored Bluetooth-to-jack test: "is sounding good so far". Wi-Fi turns off during Bluetooth streaming. See `diagnostics/audio-quality.md` for evidence and rollback.
- **Auto-Routing:** Functional. Script switches between `[Out] Headphones` and `[Out] Speaker`.
- **Auto-Pairing:** Background agent automatically accepts and trusts new pairing requests.
- **Volume Sync:** Intermittent. Works after specific permission fixes but may drop after reconnection or reboot if PulseAudio environment variables aren't strictly maintained.

## Technical Journey Summary
1.  **LineageOS 20 (Android 13):** Failed. Modern Android Bluetooth/Audio HAL too restrictive.
2.  **LineageOS 15.0 (Android 8.0):** Failed. Buggy setup.
3.  **Android 6.0.1 (Stock):** Partially successful. Required complex manual patching.
4.  **Ubuntu Touch:** **Winner.** Full Linux control allows direct manipulation of PulseAudio and BlueZ.

## Latest Session: Audio Quality and Connectivity (2026-10-21)

### Access and network findings
- USB ADB worked as user `phablet`; device serial `03057aba08e56f90`. Prefer USB during playback because the installed `bt_wifi_sync.py` disables Wi-Fi when audio starts.
- Last verified Wi-Fi address was `192.168.11.197/24` on SSID `trasla`; NetworkManager uses DHCP (`ipv4.method=auto`). No phone-side fixed IP. Router DHCP reservation was not checked. The suggested `.119` address was not this phone's verified address.
- Ping to `.197` succeeded once online. An SSH-only LAN scan previously missed the phone because no `sshd` process was running. `.1` and `.2` exposed SSH but were not identified as the phone.
- Avahi is installed but disabled at boot by `/etc/init/avahi-daemon.override` (`manual`). No mDNS name was advertised; `parlantes.local` would be the expected hostname if enabled, not `nexus.local`. SSH and mDNS were NOT enabled during this session.
- Wi-Fi link was 2.4 GHz, channel 1, approximately -59 dBm. Do not assume Wi-Fi access remains available while streaming.

### Actual playback path and quality experiments
- Source: Pixel 7a. PulseAudio profile `a2dp_source` is correct here: the remote Pixel sends stereo audio to the Nexus. It is not hands-free audio.
- BlueZ MediaTransport reports codec byte `0` (SBC), configuration bytes `21 15 02 35`: 44.1 kHz joint stereo, 16 blocks, 8 subbands, loudness allocation, bitpool range 2-53. Actual packet bitpool/bitrate was NOT measured.
- Input is 44.1 kHz stereo; `sink.primary` runs 48 kHz stereo through `output-wired_headphone`. Jack state changed from `0` (absent) to `2` after insertion. Routing was correct during the accepted test.
- Hardware policy advertises both 44.1 and 48 kHz primary output, but a working 44.1 kHz hardware-output configuration was NOT established. The Pixel only offered 44.1 kHz for this connection. Leave rates unchanged for now.
- Loopback dynamically adjusts its nominal input rate slightly for clock drift, so matching nominal rates would not necessarily eliminate resampling.
- Replaced effective `trivial` resampling with `speex-fixed-3`, then accepted `speex-fixed-4`. No buffering, codec, or system-wide rate changes were made.
- `speex-fixed-3` measured 6.87% of one CPU core over 30.01 seconds. Level 4 measured 7.23-7.33%, mean 7.28%, across six roughly 30-second windows. This is a small measured cost, not a controlled frequency/content benchmark.
- For the three-minute candidate test, PulseAudio PID stayed unchanged and Bluetooth source/jack sink were RUNNING at every checkpoint. No matching underrun messages appeared in the recent syslog tail, but there is no reliable continuous dropout counter; listening feedback and longer testing remain important.

### Failed approaches and restart cautions
- PulseAudio 8's `module-loopback` rejected `resample_method=speex-fixed-3` as a module argument. The bridge was recreated; use the daemon configuration for resampler selection instead.
- `initctl restart pulseaudio` timed out and PulseAudio came back with desktop ALSA defaults instead of the Ubuntu Touch Droid sink. Explicit `default-script-file = /etc/pulse/touch.pa` in the user override fixed selection on subsequent startup.
- The phone unexpectedly rebooted during the earlier restart attempts; cause was not determined. Do not attribute the reboot to resampler CPU load without evidence.
- A later `pulseaudio -k; sleep 2; pulseaudio --start --log-target=syslog` restored the Touch sink but disconnected Bluetooth audio. The user had to reconnect the Pixel. Agree on interruptions before restarting again.
- `sudo -n` requires a password. The successful quality change uses writable user configuration, not a root filesystem remount.

### Accepted configuration, evidence, and rollback
- Keep `speex-fixed-4`; do not keep escalating quality without a concrete listening problem. The override remains on the phone across boots, but level 4 was not separately reboot-tested.
- Working level-3 configuration is backed up on the phone at `/home/phablet/audio-quality-backup/daemon.conf`. Restore and restart instructions are in `diagnostics/audio-quality.md`; Bluetooth reconnection may be required.
- `GATES.md`: all five gates passed, including user listening acceptance. Raw CPU/playback checkpoints are in `diagnostics/audio-baseline.txt` and `diagnostics/audio-candidate.txt`.
- Prior experiment commits: `6979df7` baseline/rollback, `274c456` candidate verification, `32e91ed` listening acceptance.
- Pre-existing changes in `README.md`, `setup.sh`, `scripts/adjust-screen-timeout.sh`, and untracked power/lockscreen files were left untouched and excluded from experiment commits.

## Follow-up: Wi-Fi SSH Restored (2026-10-21)
- Supersedes the earlier observation that SSH was not enabled: key-authenticated `ssh phablet@192.168.11.197` now succeeds from this workstation.
- Root cause: `/etc/init/ssh.override` sets `manual` and forces password authentication off; `setup.sh` only restarted SSH and edited password settings, without enabling the Ubuntu Touch boot property or provisioning a public key.
- Set `persist.service.ssh=true` using `setprop` and added this workstation's existing Ed25519 public key to the phone's authorized keys. The property watcher started SSH. No password login enabled, no root filesystem edits.
- Persistent mechanism configured but not reboot-tested; Wi-Fi still switches off during Bluetooth streaming, and DHCP/mDNS limitations remain unchanged.
- Details, verification, security notes, and rollback: `diagnostics/ssh-access.md`. Installer update remains future work; existing user edits to `setup.sh` were not modified.

## Next Steps (Only If Needed)
1. Monitor longer-term listening stability; revert to the backed-up level 3 if level 4 introduces chopping.
2. If quality remains inadequate, investigate actual SBC encoding bitrate and analog cable/speaker gain before disruptive hardware-rate experiments.
3. If requested, reproduce the accepted user override in installation tooling; currently a fresh install does not include it.
4. Separate future work: enable mDNS, reserve an IP on the router, investigate volume-sync reconnect behavior, and refine auto-pairing security. SSH was restored in the follow-up, but its installer path still needs updating if fresh-install reproducibility is requested.
