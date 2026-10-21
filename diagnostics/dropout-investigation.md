# Dropout investigation: 2026-10-21

## User observations
- Moving the Pixel behind a wall/away from Nexus made chopping worse; close placement mostly helped.
- During trace: user reported a chop a few seconds before 10:10:32 while moving away, and another approximately 10:11:12 with the Pixel close. Times are approximate chat-correlated markers, not precise audio timestamps.

## Capture and findings
- Five-minute, automatically bounded btmon capture started at 10:08:54 phone time. Private raw traces remain outside Git: phone directory /home/phablet/audio-quality-backup/trace-20261021-100854; local copy /tmp/nexus-private-trace/bluetooth.btsnoop. Contains audio payload/device identifiers; do not commit or upload casually.
- Nexus Wi-Fi verified OFF during playback; speex-fixed-4 active, input 44.1 kHz, output 48 kHz. Performance governor active. No sustained CPU saturation seen in short top samples; transient scheduling stalls not excluded.
- Complete capture parsed as Linux-monitor btsnoop (datalink 2001), incoming ACL opcode 5. An initial opcode-4 inspection was discarded because that is outgoing ACL.
- 16,357 complete 616-byte incoming audio ACL records; RTP sequence and timestamp continuity checked across all of those packets: zero discontinuities, five SBC frames per packet, RTP increments 640 samples. Capture drop counter remained zero. Approximately 237.37 seconds of audio media progression.
- All inspected audio packets carried SBC bitpool 53; 119-byte SBC frames imply approximately 328 kbps encoded SBC audio (excluding transport overhead). This is not evidence of low negotiated bitrate. Does not establish fidelity of upstream source audio.
- Largest incoming audio delivery gap 66.25 ms; gaps near both approximate user events were about 65 ms, but similarly sized gaps also occurred elsewhere. Median interval about 5 ms indicates burst delivery rather than a packet every 14.51 ms (five frames at 44.1 kHz).
- Arrival-time minus RTP-media progression spanned approximately 119.91 ms across the capture, including clock drift; this is NOT a direct jitter-buffer requirement or proof of underrun.
- Both endpoints were RUNNING when checked after each reported event. This does not prove continuous uninterrupted playback between checks.
- Default syslog had no relevant playback underrun messages; concurrent syslog tail was empty. No PulseAudio debug trace or PCM output recording existed, so downstream underruns and sender-encoded silence/glitches cannot be distinguished retrospectively.
- Startup log explicitly reports: Requested sample rate 44100 but got 48000 instead. The driver returned 48 kHz despite the advertised policy support for 44.1 kHz.

## Conclusion and next experiment
No missing audio RTP sequence numbers or media timestamp jumps were found at the Nexus host interface. This weakens a simple lost-packet explanation, but does not exclude RF retransmission delays (controller retries are not visible here), Bluetooth delivery burstiness, sender-side defects, or output/scheduling/buffering problems. Distance sensitivity is real user evidence, not proof all glitches share one cause.

No audio tuning was changed during capture. Keep speex-fixed-4. Next useful test is bounded PulseAudio debug logging with exact listening markers and, if necessary, a controlled loopback-buffer comparison. More latency might tolerate delayed arrivals but is not justified as a proven fix by this trace alone. Request user consent before changing buffering or starting another playback-dependent test. No claim that chopping has been solved.
