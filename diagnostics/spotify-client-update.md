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

## Verification outcome

Selecting Parlantes again reproduced the refusal on all 51 tracks of the
context, and the client then stopped by design. The update did not fix it, and
no go-librespot version could have: the refusal is a missing PlayPlay /
LicenseVersion 2 implementation, not a version defect.

**Corrected 2026-10-26:** the follow-on conclusion that Spotify had blocked this
account was wrong. Music Assistant now plays the same account through Spotify's
own Soloist SDK. The refusal is specific to the librespot family, which is why
both `go-librespot` and `librespot` failed identically. See the Correction at the
top of `diagnostics/spotify-audio-key-root-cause.md`; the independent librespot
cross-check there remains valid, only its interpretation changed. The upstream
report referenced here documents a similar failure, not a fix:
https://github.com/devgianlu/go-librespot/issues/235

This file is therefore a closed chapter, not a pending update. MA's **Spotify
Connect** is Soloist as well (`/data/soloist/soloist`, v1.3.10.16, one process per
connected player), so the v0.10.5 binary discussed below has no role left to
play: casting and Jam work through MA without any client on the phone. Nothing
here should be re-attempted.

## Rollback

**No longer applicable as written (2026-10-26):** the backups this section refers
to were deleted during the deliberate removal of the daemon. To revisit the
experiment, re-run `bash setup-spotifyd.sh --force`, which re-downloads v0.10.5
and reinstalls the job from `scripts/`.

Historically: on the phone, stop `spotifyd`, remount `/` writable, restore the
backed-up `go-librespot` to `/usr/bin/go-librespot` with root ownership and mode
755, and restore the backed-up `config/config.yml` to
`/home/phablet/.config/go-librespot/config.yml` with phablet ownership.
Restore the root filesystem to read-only and start `spotifyd` again.
The service definition was not modified. Preserve newer credentials/state
unless a full state rollback is specifically required.
