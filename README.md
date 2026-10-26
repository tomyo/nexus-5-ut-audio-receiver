# Nexus 5 Ubuntu Touch Audio Receiver

A Nexus 5 (hammerhead) running Ubuntu Touch sends audio to a stereo through its 3.5 mm jack. Two input paths exist: Bluetooth A2DP, and Wi-Fi via AirPlay (`shairport-sync`, used by Music Assistant). Optional Spotify Connect uses a separate go-librespot installer.

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
| `shairport-sync` | AirPlay receiver for the Wi-Fi path; writes to ALSA's `pulse` plugin (see below) |

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

Spotify is served by Music Assistant on `home-zotac-01`, not by this phone. MA's
Spotify provider with the **Soloist** engine plays fine; the reverse-engineered
clients (`go-librespot`, `librespot`) never did, and both `setup-spotifyd.sh` and
the installed service are now **retired**. The script is kept for reference only
and nothing from it is installed on the device.

Spotify **Connect** is Soloist too, so casting from a phone (and Spotify Jam) does
not need a client here at all. Verified on `home-zotac-01` 2026-10-26: one
`soloist` process per connected player, for example
`/data/soloist/soloist --device-name "Music Assistant | Toda la Casa" --data-dir
/data/spotify_connect/spotify_connect_syncgroup_rtnnddql/soloist-data`, version
1.3.10.16. The `go-librespot` binary still shipped in the MA image is not what
runs. The phone lost nothing when the daemon was removed: both the library path
and the casting path go through Spotify's own SDK, and the stereo is reached over
AirPlay as `Parlantes`. Historical note: its filename
does not mean the service was ever `spotifyd` - it ran `go-librespot`, which
also published `parlantes.local` through its own Zeroconf library and caused an
Avahi hostname conflict against `avahi-daemon`.

## Replay Safety

The installers are idempotent by intent: replaying them must leave the device in
the same state rather than reintroduce known-broken settings. These guards exist
because each one was, at some point, a real regression:

- `setup.sh` resolves the PulseAudio startup script from
  `~/.config/pulse/daemon.conf` before patching it. Hardcoding
  `/etc/pulse/default.pa` was a silent no-op, because that file is never read.
- `setup.sh` and `setup-shairport.sh` both delete
  `/etc/init/avahi-daemon.override` and pin `host-name` to `DEVICE_NAME`
  (lowercased). The AirPlay job waits on `started avahi-daemon`, and an unpinned
  name lets Avahi rename itself to `<name>-2`, which changes the AirPlay SRV
  record and breaks Music Assistant with `Cannot resolve hostname`.
- The phone address lives only in `scripts/config.env` (`PHONE_HOST`). It used to
  be repeated in every installer, and they drifted out of date.
- `setup-spotifyd.sh` refuses to run without `--force`: the clients it installs
  cannot play, and its Zeroconf library caused an Avahi hostname conflict.

Two scripts support this:

| Script | Purpose |
|---|---|
| `scripts/verify-receiver.sh` | Read-only. Asserts ~18 invariants (job running, advert present, suspend-on-idle disabled, Wi-Fi power save off, retired daemon absent) and exits non-zero on any failure. Run after every replay and after every reboot. |
| `scripts/retire-spotifyd.sh` | Idempotent removal of the retired Spotify Connect daemon, including the read-only remount dance. |

```bash
bash scripts/verify-receiver.sh
```

Known limitation, not fixed by design: `bt-wifi-sync` turns Wi-Fi off while
Bluetooth streams, which kills AirPlay during a Bluetooth session. In Wi-Fi-first
mode the job is inert unless something actually pairs over Bluetooth.

## AirPlay (Wi-Fi) Path

`bash setup-shairport.sh` installs the Wi-Fi path:

```text
AirPlay (iOS/macOS/Music Assistant) -> shairport-sync -> ALSA "pulse" plugin
  -> PulseAudio sink.primary -> 3.5 mm jack -> stereo
```

Three constraints are not obvious and were each learned the hard way:

- shairport-sync **2.8.0** (the only armhf build Xenial offers) has **no native PulseAudio backend**. `pulseaudio` is not a valid `output_backend`; ALSA is the only synchronised backend, so it writes to ALSA's `pulse` PCM plugin and therefore needs `libasound2-plugins`.
- PulseAudio's `module-suspend-on-idle` parks `sink.primary` seconds after playback stops, and every new stream then clips its first note. The load line is commented out in the startup script PulseAudio **actually reads** — which is `/etc/pulse/touch.pa`, not `/etc/pulse/default.pa`, because `~/.config/pulse/daemon.conf` pins `default-script-file = /etc/pulse/touch.pa`. Patching `default.pa` looked correct, verified clean, and silently did nothing; the module reappeared on the next boot. `setup-shairport.sh` now resolves the script from `daemon.conf` instead of assuming. Backups: `/etc/pulse/touch.pa.pre-receiver` (the former holds the pristine copy).
- Ubuntu Touch ships `/etc/init/avahi-daemon.override` containing `manual` — "do not start avahi-daemon on boot" — to save power. The shairport-sync job waits on `started avahi-daemon`, so with Avahi off the job **never starts and never advertises**, which looks exactly like a broken job. The installer deletes the override (backup `.pre-receiver`) and starts Avahi. This also makes `.local` names resolve from other devices.
- The Upstart job must set `PULSE_SERVER=unix:/run/user/32011/pulse/native`. There is no session environment in an Upstart job, so shairport-sync would otherwise look for its own socket path and fail.
- The job also runs as **`phablet`** (`sudo -H -u phablet`), not root, and that is load-bearing. PulseAudio authenticates native-protocol clients with the per-user cookie at `~/.config/pulse/cookie`, resolved through `$HOME`. A root job gets `HOME=/root`, finds no cookie, and the ALSA `pulse` plugin reports `ALSA lib pulse.c:243:(pulse_connect) PulseAudio: Unable to connect: Access denied` — thousands of times, once per connection attempt, while the receiver happily advertises and looks healthy. `-H` is what makes `HOME=/home/phablet` so the cookie is found. `phablet` is allowed to publish through Avahi (verified with an `avahi-publish` test), so the receiver still advertises unprivileged.

Diagnosing this is misleading by hand: running `sudo` from an SSH login as `phablet` **works**, because `sudo` inherits `HOME=/home/phablet` and finds the cookie — the same command inside the Upstart job never sees that environment. Reproduce with a clean environment: `sudo env -i HOME=/ PULSE_SERVER=… aplay -D pulse <file>` fails, `sudo -H -u phablet env -i HOME=/home/phablet … aplay -D pulse <file>` plays.

### Audio glitches: two separate defects

Occasional chop has two unrelated causes here, and they are easy to confuse by
ear. `/var/log/upstart/shairport-sync.log` shows the receiver side; Music
Assistant's log shows the bridge side. `scripts/watch-audio-glitches.sh`
tails the MA side and prepends local timestamps, so a glitch you hear can be
matched to the event that caused it.

1. **Start of a track is truncated.** MA logs `dropped NNNNms of audio`, ~1.4 s
   here. The AirPlay provider reserves `AIRPLAY_COLD_GROUP_START_LEAD_MS`
   (2500 ms, in `providers/airplay/constants.py`) because a buffered receiver
   needs that long to seat its clock, but the Sendspin timeline hands over the
   first chunk ~1070 ms out, so the difference is discarded. That constant is
   sized for PTP-locking receivers; shairport-sync is RAOP-only and cannot be
   configured out of it. Treat it as a fixed cost of the bridged AirPlay path.
2. **Mid-stream timeline snap.** MA logs `Realigned NNNNNN µs of Sendspin
   timeline drift` (1.93 s observed). This is the audible jump. Lever: the
   per-player **Buffer depth** setting (`buffer_depth`, AirPlay provider,
   `advanced`), which deepens the receiver queue so drift is absorbed instead
   of corrected. Presets: `0` (automatic), then 500…3000 ms; 0 is what an
   unconfigured player uses. Set it in **Settings → Players → Parlantes**, and
   the change needs a player reload. Deeper queue = more latency, so raise it
   only as far as needed.
3. **Wi-Fi power save.** `iw dev wlan0 get power_save` reported `on` while the
   signal was already excellent (-36 dBm, 0% loss, 1.1 ms RTT), so the jitter
   was the radio napping between beacons, not the link. Step 7 installs
   `/etc/init/wifi-powersave.conf` and applies it immediately. Cost: a few
   percent of idle battery. Revert with `sudo iw dev wlan0 set power_save on`.

Verified from a cold boot: Avahi and shairport-sync both running ~40 s after reboot, advertising, `module-suspend-on-idle` not loaded, `sink.primary` `IDLE`, and a test tone reaching the stereo.

The two input paths are **mutually exclusive in practice**: `bt-wifi-sync` drops Wi-Fi while Bluetooth audio streams, which would kill an AirPlay session. Use one mode at a time.

The receiver advertises as `AC3A371A0866@Parlantes` on `_raop._tcp` (AirPlay 1, port 5000, `pw=false`). It does not publish `_airplay._tcp`, so AirPlay 2 features (multi-room, buffered audio) are unavailable.

Log for this path: `/var/log/upstart/shairport-sync.log`.

## Development And Evidence

Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` and `bash -n setup.sh scripts/adjust-screen-timeout.sh`.

`SESSION.md` and older diagnostics record experiments, not current deployment instructions. Their superseded automation must not be restored as a routine rollback. Current volume implementation: `diagnostics/volume-only-recovery.md`; cleanup status and outstanding device checks: `diagnostics/stable-cleanup.md`. Previous audio-quality gates are preserved in `gates/audio-quality-history.md`.
