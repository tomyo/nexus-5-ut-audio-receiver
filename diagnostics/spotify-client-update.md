# Spotify Connect client update: 2026-10-25

## Failure before update

Wi-Fi SSH to `phablet@192.168.11.197` succeeded. The Upstart job named
`spotifyd` runs go-librespot, not the spotifyd project. The installed binary's
Go module metadata identified v0.7.1. Authentication and Pixel 7a discovery
succeeded, but two different tracks failed with:

```
failed retrieving audio key: failed retrieving aes key with code 1
```

Subsequent commands reported `no primary stream`. No Spotify sink input
reached PulseAudio. The user intentionally disconnected the headphone cable
for testing; jack state 0 and `output-speaker` were appropriate.

## Applied update

With user approval, installed the official v0.10.5 Linux ARMv6 release:
https://github.com/devgianlu/go-librespot/releases/tag/v0.10.5

- All shared libraries resolved on Ubuntu Touch (glibc 2.23); `--help` ran.
- Backed up the binary, complete private configuration directory, and service
  definition to `/home/phablet/spotify-backup-before-v0.10.5/` (mode 700).
  Credentials remain on the phone and are not committed here.
- Replaced `/usr/bin/go-librespot` with root ownership and mode 755.
- Migrated `config.yml` from nested `player` settings to top-level
  `audio_backend: pulseaudio`, `initial_volume: 90`, and
  `normalisation_disabled: false`, retaining name Parlantes, bitrate 320,
  and the enabled localhost API.
- Restarted only `spotifyd`. Temporarily remounted the root filesystem writable
  for binary replacement and restored the root filesystem to read-only.
- Updated the repository's download version and configuration template.

The service logged `running go-librespot 0.10.5`, remained running as phablet,
and its localhost status API responded HTTP 204 (no active Spotify session).
The API port is dynamically assigned; initially it was 59997.
No reboot, PulseAudio restart, or Bluetooth configuration changes occurred.

Installed binary SHA-256:
`5580fc06e1caeb679c67e5a99514fa3564f7f56a9920367bc402501a120afa00`

Previous binary SHA-256:
`67db63b4c2af771987d8b307594d54319be6d09286992ea538f896320a8dfc77`

## Verification still needed

Select Parlantes again from Spotify and play a track. Successful startup does
not establish that the audio-key refusal is fixed or that audible output works.
The upstream report documents a similar failure, not a confirmed fix:
https://github.com/devgianlu/go-librespot/issues/235

## Rollback

On the phone, stop `spotifyd`, remount `/` writable, restore the backed-up
`go-librespot` to `/usr/bin/go-librespot` with root ownership and mode 755,
and restore the backed-up `config/config.yml` to
`/home/phablet/.config/go-librespot/config.yml` with phablet ownership.
Restore the root filesystem to read-only and start `spotifyd` again.
The service definition was not modified. Preserve newer credentials/state
unless a full state rollback is specifically required.
