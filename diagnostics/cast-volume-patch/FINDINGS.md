# Nest Hub (Sendspin over Cast) ignores the Cast volume mixer

Investigated 2026-10-26 against Music Assistant `2.11.0b7` (`ghcr.io/music-assistant/server:beta`).

## Symptom

Volume slider for the **Kitchen display** (Google Nest Hub) in the MA app and web UI
moves, but loudness never changes. Parlantes (AirPlay, Nexus 5) controls fine.

## What actually happens

1. The user's slider reaches MA and is dispatched correctly.
   Instrumented `providers/chromecast/player.py::volume_set` logged 18 events, every
   one forwarded to the linked protocol player, zero resolution errors:

   ```
   VOLPATCH volume_set 40 app_id=DD107DDB linked=['spb_dce55ba0c799']
   VOLPATCH forwarding to protocol player spb_dce55ba0c799
   ```

2. The Cast device accepts and reports every value. Driven directly with
   `pychromecast` from inside the container, bypassing MA entirely:

   ```
   app: DD107DDB            # Sendspin over Cast (MA 2.9)
   FULL  (5s) -> device 1.0
   SILENT(8s) -> device 0.0
   FULL  (5s) -> device 1.0
   ```

   Later, with audio playing, `vol: 0.0, muted: False` and the speaker was **still
   loud** — audible to the user, twice, in independent tests.

3. Therefore the receiver web app renders audio outside the device mixer's control.
   MA cannot fix this: it sends the volume, the device stores it, the app ignores it.
   Sending the value over the Sendspin protocol instead (`VolumeChangedEvent` via
   `bridge_role.py:271`) makes no difference either — that path was instrumented and
   forwarded for all 18 events.

## Ruled out along the way

- **Missing volume forwarding in the bridge** — forwarded for every event, no change.
- **Defer-idle-volume / CVAA interference** — device was in a real playing session
  (`app_id=DD107DDB`, player UI on screen), not idle.
- **Wrong player receiving the command** — driver logs show the correct player.
- **Native-vs-protocol volume routing** — `controllers/config/players.py:874-877`
  never offers the protocol player as a volume option when the parent has native
  volume (`if has_native_volume_control: break`), so routing is not selectable; the
  Chromecast player writes `cc.set_volume`, which the device honours at its own layer.
- **Beta regression** — upgraded 2.10.8 → 2.11.0b7 mid-investigation; identical
  behaviour, so this is not a beta artifact.

## Confounder worth remembering

The Nest Hub was **not** the speaker producing sound for most of the session: it sat
in ambient/backdrop mode (`app_id=E8C28D3C`, the default receiver) while Parlantes
played. Muting the phone and hearing "music continue" was misread as "the Nest is
audible". The user spotted the tell: the photo frame stayed on screen during
playback. Only after forcing play on the group did the device show the player UI.

A separate, real MA bug surfaced in the same session: pressing play on the Kitchen
display alone stole the single Spotify stream slot from the group
(`Stopping paused queue Kitchen display, another queue needs its spotify--G7BAGapB
stream slot`), after which MA set the player back to `Sendspin` without relaunching
the cast app, leaving it in the default receiver while MA believed Sendspin was
active.

## Status

- Volume experiment reverted; container recreated clean from the `:beta` image.
- Nothing patched on the Zotac or the phone.
- Workaround options: use a Cast target whose app respects the mixer, or drop that
  device from the sync group, or accept fixed loudness on it.
