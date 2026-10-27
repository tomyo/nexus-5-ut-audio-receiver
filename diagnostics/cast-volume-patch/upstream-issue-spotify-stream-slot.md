# Spotify stream slot never released: playback to another player deadlocks the provider

Music Assistant `2.11.0b7`, Spotify provider (Soloist engine), Docker on Linux.

## Summary

With a Spotify queue playing on one player (a group), starting playback on a
**different** player permanently consumes Spotify's single stream slot. Every following
request fails with `Spotify has reached its limit of 1 concurrent source streams after
waiting 15 seconds`, nothing plays on either player, and the only way back is restarting
the server container.

## Repro

1. Player A = group `Toda la Casa` (AirPlay + Cast member). Start Spotify playback on it.
2. Player B = a single Cast player. Choose/play any Spotify track on B.
3. **Actual:** audio stops on both. Player B's screen keeps the previous artwork and
   appears frozen; pressing play again does nothing. No error is surfaced in the UI.
4. **Expected:** playback moves to B (or A keeps playing with a clear "busy" error) —
   the slot should be released by whichever queue is stopped.

Log, from the repro (repeated on every subsequent press, one per attempt):

```
21:24:46 ERROR player_queues] Spotify has reached its limit of 1 concurrent source streams after waiting 15 seconds.
21:24:46 WARNING webserver] players/cmd/play_pause: Spotify has reached its limit ...
21:24:48 WARNING webserver] players/cmd/play_pause: Resume queue requested but queue MassDroid is empty
21:25:01 ERROR ... 21:25:06 ERROR ... 21:25:19 ERROR ... 21:25:37 ERROR ... 21:26:04 ERROR
```

Earlier, the *opposite* direction behaved sensibly — MA stopped a queue to free the slot:

```
20:56:13 INFO player_queues] Stopping paused queue Kitchen display, another queue needs its spotify--G7BAGapB stream slot
```

So the release path exists for a **paused** queue but not for the actively-playing queue
that the user is switching away from.

## Hypothesis

The slot is `asyncio.BoundedSemaphore(max_concurrent_streams)` created in
`models/music_provider.py:224`, limit 1 for Spotify. Playback stops on both players, yet
the provider still reports the limit minutes later, which points at the semaphore never
being released when the original queue's stream task is torn down — i.e. a leak, not a
slow release. `controllers/streams/audio_buffer.py:991` and
`controllers/player_queues/stream_feeder.py:502` both special-case
`max_concurrent_streams == 1`, so the single-slot path is clearly meant to hand over
cleanly.

## Impact

Recovery requires `docker restart music-assistant`. Until then the Spotify provider is
unusable for every player, including the one that was working before.

## Secondary issues seen in the same session

- The UI silently does nothing when this happens: the error is returned over the
  websocket (`players/cmd/play_pause`) but no user-visible message appears.
- The Cast player keeps showing stale artwork with no playback, indistinguishable from
  a hung device.
