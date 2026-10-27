# Nest Hub volume: the mixer can wedge mid-session (reboot clears it)

Investigated 2026-10-26 against Music Assistant `2.11.0b7`
(`ghcr.io/music-assistant/server:beta`). **Not filed upstream — not reproducible after
a reboot, and the earlier conclusions below were wrong.**

## Final state

After rebooting the Nest Hub, volume control works for **both** players from the MA web
UI: Parlantes (AirPlay, Nexus 5) and Kitchen display (Sendspin over Cast). Nothing is
patched on the Zotac or the phone, and MA is on the stock `:beta` image.

## What happened before the reboot

- MA dispatched every slider move correctly: instrumenting
  `providers/chromecast/player.py::volume_set` logged 18 events, each forwarded to the
  linked protocol player, no resolution errors.
- The device accepted and echoed every value (`CastStatus.volume_level` read back
  exactly), including `0.0` with `volume_muted = False`.
- Audio kept playing at unchanged loudness at **any** device volume, and the Nest's own
  on-screen volume indicator moved in response to hardware buttons while the cast app's
  screen ignored it.
- Casting **Spotify directly** to the same device showed the same behaviour — Spotify's
  volume UI moved, loudness did not. That is what disproved the "MA's receiver app
  renders its own gain" theory: Spotify is not MA's app.

## After reboot: everything behaves

- Spotify's own volume control worked immediately.
- Direct control, bypassing every app:

  ```
  app: CC32E753 | vol now: 0.5
  SILENT 8s -> device 0.0     (audibly silent)
  restored  -> device 0.35    (audible again)
  ```

- Then MA's Sendspin over Cast receiver took over without issue and its volume works
  too, from the web UI.

## Probable trigger

The session in which it broke involved MA switching the player's output protocol
mid-playback (`Setting active output protocol on Kitchen display to Native`, then back
to `Sendspin` 20 seconds later, in the middle of a Spotify stream-slot conflict). A
suspended/idle receiver appears to be able to leave the platform mixer inert across
subsequent apps until the device restarts.

Unproven: the trigger was not reproduced after the reboot, so this remains a hypothesis
with a known recovery step (reboot the Cast device), not a defect with a repro.

## Lesson worth keeping

For a whole evening, "the Nest Hub ignores volume" was explained by a plausible-looking
code path (`if has_native_volume_control: break` in
`controllers/config/players.py:874-877`, which genuinely does prevent choosing the
protocol player as volume target). The device evidence pointed the other way, and the
cheap test — a different app on the same hardware — is what exposed it. Check the
device with a second, independent app before reading MA's source.
