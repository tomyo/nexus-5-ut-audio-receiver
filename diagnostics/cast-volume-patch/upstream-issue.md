# Sendspin over Cast receiver ignores Cast volume and publishes no media session

## Environment

- Music Assistant server `2.11.0b7` (`ghcr.io/music-assistant/server:beta`), Docker, host networking
- Cast receiver app as reported by the device: `Sendspin over Cast (MA 2.9)`, app id `DD107DDB`
- Device: Google Nest Hub (1st gen)
- Player `spb_dce55ba0c799 / Kitchen display (Cast)`, Sendspin client over Cast
- Reproduced identically on `2.10.8`, so this is not a 2.11 beta regression

## Steps

1. Group playback to `Toda la Casa` (Nexus 5 AirPlay player + this Nest Hub).
2. Move the volume slider for `Kitchen display` in the MA app, or press the Nest Hub's
   hardware volume buttons, or set the volume directly with `pychromecast`.

## Expected

Audible loudness changes, and the receiver shows the current volume.

## Actual

- MA dispatches correctly and the device accepts every value.
- The Nest Hub's own on-screen volume indicator moves, and `CastStatus.volume_level`
  reads back the exact commanded value.
- **Audio keeps playing at unchanged loudness** at any device volume, including `0.0`
  with `volume_muted = False`.
- The receiver's own UI keeps showing its previous volume (0%), unaffected by either
  the MA slider or the hardware buttons.
- The receiver's screen shows a track timeline already at 100% while audio continues.

## Evidence

The MA volume path is intact. Instrumenting
`providers/chromecast/player.py::volume_set` shows every UI change arriving and being
forwarded to the linked protocol player:

```
VOLPATCH volume_set 40 app_id=DD107DDB linked=['spb_dce55ba0c799']
VOLPATCH forwarding to protocol player spb_dce55ba0c799
```

Driving the device directly with `pychromecast` inside the server container, fully
bypassing MA, reproduces it:

```
app: DD107DDB
FULL  (5s) -> device 1.0
SILENT(8s) -> device 0.0
FULL  (5s) -> device 1.0
```

The media session is empty while audio plays:

```
state: UNKNOWN | t: 0.0 | dur: None | vol: 0.0 | app: DD107DDB
```

Forwarding the value over the Sendspin protocol instead
(`bridge_role.py:271` → `VolumeChangedEvent`, delivered for every one of the 18 slider
events) also changes nothing.

## Likely cause

The receiver renders audio through its own gain node and does not apply Cast volume
events to it, and it never publishes a Cast media session, so the platform has no
session to bind volume or progress to. Anything the platform does to the mixer is
therefore inaudible, and the app's displayed volume/progress comes only from the
Sendspin protocol.

## Suggested direction

Either publish a media session and let the platform own volume, or apply incoming
Cast volume changes (CAF `VolumeChanged` / the `cast.framework` volume callbacks, or
`HTMLMediaElement.volume`) to the gain node in use.

## Note on a separate issue

Starting playback on this single Cast player while the group is playing takes over the
single Spotify source stream slot
(`Stopping paused queue Kitchen display, another queue needs its spotify--G7BAGapB
stream slot`) and then sets the player's active output protocol back to `Sendspin`
without relaunching the receiver, leaving the device on the default receiver while MA
reports Sendspin as active. Happy to file that one separately with logs.
