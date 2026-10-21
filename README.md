# Nexus 5 Ubuntu Touch Audio Receiver

A Nexus 5 (hammerhead) running Ubuntu Touch receives Bluetooth A2DP audio and sends it to a stereo through its 3.5 mm jack. Optional Spotify Connect uses a separate go-librespot installer.

## Stable Playback Contract

- PulseAudio's built-in Bluetooth policy owns profiles and audio bridges. No custom watchdog creates, removes, or redirects loopbacks.
- `scripts/vol_sync.py` maps a single active incoming sender's BlueZ volume to `sink.primary`. Pixel volume buttons were confirmed working. Nexus-to-Pixel volume synchronization is intentionally absent.
- User PulseAudio configuration selects the Touch startup script and `speex-fixed-4` resampling. Hardware output may remain 48 kHz while Bluetooth input is 44.1 kHz.
- Keep policy-default buffering. No explicit 200 ms target is installed. If chopping returns, measure current latency before a reversible buffer experiment; larger latency is not a proven cure.
- Short listening tests are not a guarantee of dropout-free playback. See `diagnostics/dropout-investigation.md`.

## Services

| Service | Responsibility |
| --- | --- |
| `vol-sync` | Sender volume to output only; also retains the existing CPU performance-governor setup |
| `jack-sense` | Select `sink.primary` headphone/speaker port; retry failed switches |
| `bt-wifi-sync` | Turn Wi-Fi off during incoming Bluetooth audio and on when idle; no DNS edits or Spotify restarts |
| `bt-agent` | Discoverable, automatic no-input pairing; use only on a trusted network/physical site |
| `keep-awake` | Hold a hardware wakelock while externally powered; increases power/heat |

Wi-Fi automation intentionally manages the radio even if it was manually disabled. Use USB ADB during playback: Wi-Fi SSH will disappear when streaming begins. Bluetooth services start with system D-Bus rather than depending on Wi-Fi association. Spotify still needs Wi-Fi.

Automatic pairing accepts nearby requests without a PIN confirmation and authorizes services. This is convenient, not hardened pairing. It is retained, not silently broadened by the cleanup.

## Setup

1. Enable Developer Mode, connect USB, and confirm `adb devices` shows the phone.
2. Review `scripts/config.env` locally (contains credentials; do not publish real secrets).
3. Run `bash setup.sh` from the repository root. Each section asks permission; it can remount the phone filesystem writable and change system settings. Do not run the full installer just to update one helper.
4. Reboot only when ready for a playback interruption. Pair/connect as **Parlantes**, connect the analog cable, and play audio.
5. Verify output, Pixel volume, pause/resume, reconnect, and reboot using `diagnostics/stable-cleanup.md`.

Setup preserves saved Bluetooth bonds, installs the tested user resampler override, and renders service configuration without modifying repository templates. A speaker class/name is only an identity request, not proof of controller class or a requirement for computer compatibility. No new D-Bus permissions or BlueZ upgrade is required.

SSH on Ubuntu Touch also depends on its persistent service property and authorized keys; see `diagnostics/ssh-access.md`. A `.local` hostname requires Avahi actually enabled; a hostname alone does not prove mDNS works. Never remove the lockscreen before verifying a separate administrator login. Setup creates a locked rescue account, not a default-password backdoor; set its password interactively first.

Spotify installation remains separate: `bash setup-spotifyd.sh`. Its historical filename does not mean the active service is spotifyd. Spotify and fresh-install behavior are not certified by Bluetooth unit tests.

## Development And Evidence

Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` and `bash -n setup.sh scripts/adjust-screen-timeout.sh`.

`SESSION.md` and older diagnostics record experiments, not current deployment instructions. Their superseded automation must not be restored as a routine rollback. Current volume implementation: `diagnostics/volume-only-recovery.md`; cleanup status and outstanding device checks: `diagnostics/stable-cleanup.md`. Previous audio-quality gates are preserved in `gates/audio-quality-history.md`.
