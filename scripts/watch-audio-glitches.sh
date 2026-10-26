#!/bin/bash
# Watch Music Assistant's AirPlay bridge for the events that are audible.
#
# Two different defects show up here and they are easy to confuse by ear:
#   "dropped NNNNms of audio"        -> start of a track is truncated
#   "Realigned NNNNNN us of drift"    -> mid-stream jump/click, the "chop"
#
# Run this in a second terminal, play music, and note the wall-clock time when
# you hear a glitch. The local timestamps below make that correlation possible
# without guessing which defect you are hearing.
#
#   ./scripts/watch-audio-glitches.sh
#   MA_HOST=tomyo@other-host ./scripts/watch-audio-glitches.sh
set -uo pipefail

MA_HOST="${MA_HOST:-tomyo@192.168.11.2}"
MA_LOG="${MA_LOG:-/media/data-01/music-assistant/data/musicassistant.log}"

echo "Watching $MA_HOST:$MA_LOG"
echo "Patterns: dropped <n>ms of audio | Realigned <n> us of drift | could not be audible"
echo "Ctrl-C to stop. Local time is prepended to each event."
echo

# --line-buffered so events appear as they happen instead of in tail's chunks.
ssh -o BatchMode=yes "$MA_HOST" "tail -F '$MA_LOG'" \
    | grep --line-buffered -E 'Realigned [0-9]+ .*drift|dropped [0-9]+ms of audio|could not be audible' \
    | while IFS= read -r line; do
        printf '%s  %s\n' "$(date '+%H:%M:%S')" "$line"
    done
