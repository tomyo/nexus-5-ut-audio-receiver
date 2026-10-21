# Bluetooth quality experiment

## Baseline
- Phone: Nexus 5, PulseAudio 8.0, Pixel 7a source.
- Saved working override on phone: /home/phablet/audio-quality-backup/daemon.conf.
- Baseline override includes /etc/pulse/daemon.conf, selects speex-fixed-3 and /etc/pulse/touch.pa.
- Active Bluetooth transport: Codec byte 0 (SBC); Configuration bytes 21 15 02 35.
- SBC configuration decodes to 44.1 kHz, joint stereo, 16 blocks, 8 subbands, loudness allocation, bitpool range 2-53. Actual packet bitpool/bitrate has NOT been captured; the configured range is not proof of actual encoding quality.
- Jack sink: 48 kHz stereo, output-wired_headphone. Bluetooth source: 44.1 kHz stereo.
- Baseline PulseAudio CPU: 6.87% of one core over 30.01 seconds (see audio-baseline.txt). Not total-system CPU.
- Syslog is readable, but its recent tail contains no PulseAudio runtime diagnostics. Absence of messages does not establish absence of underruns.

## Candidate and current state
- Changed only resample-method from speex-fixed-3 to speex-fixed-4 in the user override.
- Restarted PulseAudio using pulseaudio -k followed by pulseaudio --start --log-target=syslog, not the Upstart restart command.
- Touch hardware sink recovered with correct jack route; Bluetooth source disappeared after restart, then recovered after the user reconnected the Pixel.
- Live loopback verified speex-fixed-4. Six approximately 30-second measurements over three minutes: 7.33, 7.30, 7.27, 7.30, 7.26, 7.23 percent of one core (mean 7.28 percent), versus baseline 6.87 percent. Roughly 0.41 percentage points more; measurements are not a controlled audio-content/CPU-frequency benchmark.
- PulseAudio PID remained 19155; source and sink were RUNNING at each checkpoint, with wired headphone routing verified at completion. No matching PulseAudio/underrun messages in the recent 150-line syslog tail, but this is not continuous dropout detection.
- Candidate remains configured provisionally. Listening acceptance is PENDING; do not call this an audible improvement yet. Raw results: audio-candidate.txt.
- No sample-rate, buffering, Bluetooth codec, or system-wide settings changed.

## Rollback via USB
Restore the saved override:

```sh
adb shell 'cp /home/phablet/audio-quality-backup/daemon.conf /home/phablet/.config/pulse/daemon.conf'
```

Then restart PulseAudio during an agreed interruption:

```sh
adb shell 'pulseaudio -k; sleep 2; pulseaudio --start --log-target=syslog'
```

Reconnect the Pixel and resume music. Verify `pactl list sink-inputs` reports speex-fixed-3 and `pactl list sinks` reports output-wired_headphone. Restarting audio interrupts Bluetooth and may require reconnection; a previous session experienced an unexplained reboot, so avoid repeated restarts.
