# Spotify audio-key refusal: root cause, 2026-10-25

## Correction, 2026-10-26: the account was never the problem

**The verdict below is wrong, and is kept only as a record of the evidence.** It
concluded that Spotify blocked playback at the account level. It did not.

The discriminator missing on 2026-10-25 was not a second Spotify account but a
third implementation. Music Assistant on `home-zotac-01` plays this same account
through its Spotify provider using **Spotify's own Soloist SDK**
(<https://developer.spotify.com/documentation/soloist>), with the same
`country: AR` / `pr:premium` token, and it plays the very tracks both
reverse-engineered clients refused.

```
INFO (MainThread) [music_assistant.spotify] Successfully logged in to Spotify as Tomás Hayes
INFO (MainThread) [music_assistant.spotify] Developer Spotify session active.
INFO (MainThread) [music_assistant] Loaded music provider Spotify
```

What survives the correction, unchanged:

- The refusal is real, reproducible and not track-specific. `error audio key 0 1`
  is what `librespot` and `go-librespot` get on this account.
- It is not caused by the phone, PulseAudio, the bitrate, the country, or the
  file selection. Those exclusions still stand.
- Both clients fail identically, so it is not one project's bug.

What was wrong: "no local configuration change can fix it" is true, but
"Spotify refuses this account" does not follow. The narrow, correct statement is
that **these clients cannot complete this account's licensing flow, and
Spotify's own SDK can.** The account's `financial-product` pins an `rt:v2_…`
(PlayPlay / LicenseVersion 2) flow; the librespot family has no PlayPlay
implementation, so it receives a key refusal where Soloist performs a licence
negotiation. No account was ever blocked, and a second account was never needed.

Practical consequence: the phone's Spotify daemon is retired
(`setup-spotifyd.sh` refuses to run without `--force`, and
`scripts/retire-spotifyd.sh` asserts removal). Spotify reaches the stereo through
Music Assistant -> AirPlay -> `Parlantes`, and that path works.

### Follow-up, 2026-10-26: MA's Connect is Soloist too

A plausible objection to the verdict above is that Music Assistant might have
restored the librespot family and made the whole diagnosis moot. It did not.
Checking the running MA container shows Spotify's Soloist daemon serving
**Connect** as well:

```text
/data/soloist/soloist --device-name "Music Assistant | Toda la Casa"
  --data-dir /data/spotify_connect/spotify_connect_syncgroup_rtnnddql/soloist-data
  --cache-dir /data/.cache/spotify_connect_... --cache-size 512 --initial-volume 100
```

One `soloist` process per player listed in
`spotify_connect.connected_players`, version 1.3.10.16, alongside a Soloist
Crashpad handler. `go-librespot` is still present at `/usr/local/bin` in the
image but nothing executes it. So the discriminator is the **implementation**, in
both roles: library playback and phone casting/Jam alike are licence-negotiated
by Spotify's SDK, which is exactly why the account never needed to be replaced
and why the standalone clients on the phone could not be fixed from there.

## Original verdict (2026-10-25) - SUPERSEDED, DO NOT TRUST

The text from here to "Ruled out" is preserved as written at the time. It is
retained because the evidence it cites is valid; only its conclusion is wrong.

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

*(Wrong as a diagnosis: the blocking factor is the clients' missing PlayPlay
support, not a policy on the account. the account plays fine through Spotify's
own SDK. See the Correction at the top.)*

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
newly-created account, and `rt:v2_…` marks the PlayPlay / LicenseVersion 2
licensing flow. That part was read correctly: this account is served the newer
flow. What was misread is *who fails* it. Soloist completes that flow; the
librespot family never implemented it, so they are refused rather than
negotiated with. The upstream reports below therefore describe a client gap that
correlates with new accounts - not an account ban.

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
| A defect in one client | Both clients fail identically - but "both fail" only proves they share a limitation, not that the account is refused. Soloist, a third implementation, plays the same track (see Correction) |
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

## What resolved it, and what is still unknown

A second account was never required. The missing control was an implementation
that *supports* the flow, and Music Assistant's Spotify provider (Soloist) is
one, running the same account.

The original reasoning contained a trap: "the same account works in the official
Spotify app" was read as evidence *for* an account-level policy, when it was
evidence *against* one, because the official app uses Spotify's own playback SDK
exactly as Soloist does. Two observations said "Spotify's SDK plays this
account" and one said "reverse-engineered clients do not"; that is a statement
about the clients.

Still unknown, and irrelevant to the working setup: whether the librespot family
could ever complete PlayPlay, and whether the refusal is a hard block or a
failed negotiation. go-librespot issue #317 tracks the missing implementation;
the practical resolution here was to stop using those clients.

## If this is ever retried

PlayPlay / LicenseVersion 2 is the protocol that carries the key for these
accounts. Soloist implements it; neither librespot nor go-librespot had as of
2026-10-25. Anyone retrying a librespot-family client should first confirm
PlayPlay support upstream (go-librespot #317), otherwise the result is the same
`error audio key 0 1`.

Audio on this device no longer depends on any of it: AirPlay -> `Parlantes`
carries Spotify from Music Assistant, and the receiver path is independent of
Spotify entirely.

## State at time of writing

- Phone: go-librespot v0.10.5 running under the `spotifyd` Upstart job,
  advertising as `Parlantes`; root filesystem restored to read-only.
- Workstation: test container stopped and removed; firewall port 39999 closed
  (persisted ports unchanged: `1025-65535/tcp`, `1025-65535/udp`).
- Superseded binaries parked on the phone as `*.bak` files listed above.

### State after the correction (2026-10-26)

- `go-librespot`, its `~/.config/go-librespot` identity and the `spotifyd`
  Upstart job are **removed** from the phone; `scripts/retire-spotifyd.sh`
  asserts that state and frees ~59 MB.
- Spotify plays through Music Assistant on `home-zotac-01` using Soloist, then
  AirPlay to `Parlantes` (see the AirPlay section of `README.md`).
- `scripts/verify-receiver.sh` checks the receiver invariants, including that no
  `_spotify-connect` advertisement has come back.
- The table above about glibc and prebuilt clients is still accurate but now
  only historical: no librespot-family client is needed on the phone.
