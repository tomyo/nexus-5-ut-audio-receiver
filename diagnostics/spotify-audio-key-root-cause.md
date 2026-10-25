# Spotify audio-key refusal: root cause, 2026-10-25

## Verdict (as of this date)

Spotify accepts the session, serves track metadata, serves the CDN file URL,
and lets the client download the **entire encrypted audio file**, but refuses
to issue the **decryption key**:

```
ERROR librespot_core::audio_key] error audio key 0 1
```

This is a server-side decision on the Spotify account, not a defect in the
phone, the audio stack, the bitrate, or any particular client build. Two
independent implementations — go-librespot (Go) and librespot (Rust) — reach
the same wall on the same track with the same account. No local configuration
change can fix it, and no newer prebuilt client exists that can either.

Spotify Connect playback on this device is therefore **blocked by an upstream
policy**, pending either an upstream implementation of the newer license
exchange (`PlayPlay` / `LicenseVersion 2`) or an account that is not subject to
it.

## Evidence 1 — the phone's client (go-librespot v0.10.5)

Log: `/var/log/upstart/spotifyd.log` (root-readable only).

```
WARN[0040] skipping track: Spotify refused the audio key (code 1) for this playback context: spotify:track:0t0Kl5jxxV3s8bdpILkgmd
          error="failed creating stream for spotify:track:0t0Kl5jxxV3s8bdpILkgmd: failed retrieving audio key: failed retrieving aes key with code 1"
…
WARN[0059] failed load spotify:track:6VPIaZNNJFOY9U17geQz1o  error="failed creating stream …: failed retrieving aes key with code 1"
WARN[0059] stopping after 51 consecutive unplayable tracks
WARN[0059] failed loading station for spotify:album:1qaq3gfrFUMwNoZ5lM2i7z
          error="failed loading current track (load context): failed advancing past unplayable track: … failed retrieving aes key with code 1"
```

Every track in the album context is refused — 51 of 51, then the client stops
by design. The failure is universal within a context, so it is not
track-specific licensing.

## Evidence 2 — an independent client on separate hardware

To exclude go-librespot as the cause, librespot v0.8.0 (Rust, from the Arch
`extra` package) was run on a workstation in a throwaway rootless podman
container, advertising as `TEST-librespot`, with no audio hardware at all:

```bash
sudo firewall-cmd --add-port=39999/tcp      # runtime only, removed afterwards
podman run -d --rm --name librespot-test --network host docker.io/library/archlinux \
  bash -c 'pacman -Sy --noconfirm librespot >/dev/null 2>&1 && \
           exec librespot --backend pipe --device /dev/null --bitrate 320 \
                --name TEST-librespot --zeroconf-port 39999 --verbose'
```

Playback was transferred from the Pixel 7a to `TEST-librespot`. Trace
(2026-10-25, UTC):

```
19:18:50  INFO  librespot_playback::player] Loading <Lunes Por La Madrugada> with Spotify URI <spotify:track:6VPIaZNNJFOY9U17geQz1o>
19:18:50  DEBUG librespot_core::http_client] Requesting …/storage-resolve/files/audio/interactive/88bcd787b5febf33bfe58300b3218fd26004f9f2?product=0&country=AR
19:18:51  ERROR librespot_core::audio_key] error audio key 0 1
19:18:51  WARN  librespot_playback::player] Unable to load key, continuing without decryption: Service unavailable { audio key error }
19:19:04  ERROR librespot_core::audio_key] error audio key 0 1          # retry, identical
19:19:04  DEBUG librespot_audio::fetch] Downloading file 88bcd787… complete
19:19:15  ERROR librespot_playback::player] Unable to read audio file: Symphonia Decoder Error: end of stream
19:19:15  ERROR librespot_playback::player] Skipping to next track, unable to load track <SpotifyUri("spotify:track:6VPIaZNNJFOY9U17geQz1o")>: ()
19:19:15  DEBUG librespot_connect::state::tracks] marking spotify:track:6VPIaZNNJFOY9U17geQz1o as unavailable
19:19:15  ERROR librespot_connect::spirc] could not dispatch player event: Invalid state { context is not available. type: Autoplay }
```

Reading the order matters: metadata and file resolution succeed, the complete
encrypted file downloads, and **only the key is withheld**. `Symphonia Decoder
Error: end of stream` is not a corrupt download — the decoder is reading
ciphertext because the key never arrived. Both clients then mark the track
unavailable and skip.

## Account signature

The authenticated token for this account carries:

```
country: AR
financial-product: pr:premium,tc:0,rt:v2_AR_default_new-family-sub-1m_0_ARS_default
```

The subscription is a premium **family** plan, `family-sub-1m`, on a
newly-created account. This matches the reported condition exactly: newly
provisioned Premium accounts are served the newer license flow, while older
accounts keep receiving legacy AES keys.

Upstream reports:

- librespot issue #1735 — one Premium account refused, another succeeds on the
  same machine: https://github.com/librespot-org/librespot/issues/1735
- go-librespot issue #317 — legacy AES refused for license-gated tracks, needs
  PlayPlay: https://github.com/devgianlu/go-librespot/issues/317
- go-librespot issue #235 — "I am not having this problem with the rust
  librespot version": https://github.com/devgianlu/go-librespot/issues/235
  (note: this exact claim was **disproven here** — librespot 0.8.0 fails
  identically, so the difference is the account, not the implementation)

## Ruled out, with the check that ruled it out

| Hypothesis | How it was excluded |
|---|---|
| Audio routing / PulseAudio / speakers | Failure occurs before any decoded PCM exists; a `pipe → /dev/null` backend on a different machine reproduces it |
| Bitrate 320 vs 160 | Refusal is at key exchange, before file selection by quality |
| Track-specific licensing | All 51 tracks of the context refused |
| Wrong country / no streaming rights | Same account plays normally in the official Pixel 7a app; `country: AR`, `player-license: premium` |
| Free / expired account | Token reports `pr:premium`, `catalogue: premium`, `name: Spotify Premium` |
| Stale go-librespot build | v0.10.5 (current, includes the file-id/`alternative` fix from #235) fails the same way |
| Client-implementation bug | Independent Rust client fails identically on the same track |
| Wrong file selected (issue #235) | Requested file id `88bcd787b5febf33bfe58300b3218fd26004f9f2` downloads complete; only the key is denied |

## No usable newer spotifyd exists for this phone

The device runs glibc **2.23**, which blocks every prebuilt librespot-family
binary:

| Build | Requirement | Result on phone |
|---|---|---|
| spotifyd v0.4.2 armv7 `default` | GLIBC_2.30 | fails to load |
| spotifyd v0.4.2 armv7 `full` | GLIBC_2.30 | fails to load |
| spotifyd v0.4.2 armv7 `slim` | GLIBC_2.30 | fails to load |
| spotifyd v0.3.5 armv6 | GLIBC_2.25+ | fails to load |
| spotifyd v0.2.24 armv6 | ELF 2.6.32 | loads, but 2019-era client; ALSA-only on this path |
| librespot v0.8.0 | — | publishes **no binaries at all** |
| go-librespot v0.10.5 | pure Go, static | runs (the only one that does) |

`/usr/bin/spotifyd` is now the v0.2.24 binary left by an earlier attempt; the
working client is `/usr/bin/go-librespot`. Superseded binaries are parked as
`/usr/bin/spotifyd.v0.2.24.bak` and `/usr/bin/spotifyd.v0.4.2.bak`.

Any librespot-family client on this phone would have to be cross-compiled
against glibc ≤ 2.23 (or fully static, musl) — and, per the evidence above,
it would fail anyway for this account.

## Remaining uncertainty

The single untested discriminator was **a second, older Spotify account**. The
account holder does not have one, so account-specificity remains strongly
indicated rather than proven. It is evidenced by:

- the `family-sub-1m` newly-provisioned subscription signature,
- the same failure across two independent client implementations,
- the same account working normally in the official Spotify app,
- the public reports correlating new accounts with this exact refusal.

If a second account ever becomes available, the check costs ~5 minutes and
needs no phone changes: re-run the container recipe above, transfer playback to
`TEST-librespot`, and look for `Loading <track>` followed by a decoded stream
instead of `error audio key 0 1`.

## If this is ever retried

Watch for upstream implementing `PlayPlayRequest` / license-version 2, the
protocol that carries the key for gated accounts. Neither librespot nor
go-librespot had implemented it as of 2026-10-25. Until then, no version of
either client will play this account, and only Bluetooth (the device's primary
purpose) produces audio.

## State at time of writing

- Phone: go-librespot v0.10.5 running under the `spotifyd` Upstart job,
  advertising as `Parlantes`; root filesystem restored to read-only.
- Workstation: test container stopped and removed; firewall port 39999 closed
  (persisted ports unchanged: `1025-65535/tcp`, `1025-65535/udp`).
- Superseded binaries parked on the phone as `*.bak` files listed above.
