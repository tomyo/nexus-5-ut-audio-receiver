# Gates: Bluetooth jack audio quality experiment

Scope: Diagnose codec and playback headroom, test one reversible quality improvement, and retain only a stable candidate. No guarantee of zero dropouts beyond the measured window.

- [x] G1: Save working phone configuration and exact rollback steps before changing audio.
  EVIDENCE: Saved /home/phablet/audio-quality-backup/daemon.conf; diagnostics/audio-quality.md documents restore and restart commands.
- [x] G2: Record live Bluetooth codec evidence, sample rates, jack routing, CPU baseline, and available dropout diagnostics; distinguish unavailable evidence from confirmed facts.
  EVIDENCE: BlueZ SBC configuration 21 15 02 35; 44.1 kHz input, 48 kHz jack; baseline 6.87% one-core CPU over 30.01 seconds; actual bitrate and reliable underrun counters unavailable. See diagnostics/audio-quality.md.
- [x] G3: Test one resampler quality step with a verified active setting and correct jack routing, or restore baseline if unsafe.
  EVIDENCE: Live loopback reports speex-fixed-4; sink and Bluetooth source RUNNING; output-wired_headphone verified. See diagnostics/audio-candidate.txt.
- [x] G4: Compare CPU over equal playback windows and monitor stability for at least three minutes; record limits of dropout detection.
  EVIDENCE: Six approximately 30-second windows: 7.33, 7.30, 7.27, 7.30, 7.26, 7.23 percent of one core versus baseline 6.87 percent over 30 seconds. Same process and RUNNING endpoints at every checkpoint. No matching messages in recent syslog tail; no reliable continuous underrun counter. Audible stability requires G5.
- [x] G5: Obtain listening feedback before calling the candidate better, and document retained settings and rollback.
  EVIDENCE: User feedback after candidate test: "is sounding good so far". Retain speex-fixed-4; feedback supports acceptable playback so far, not a proven improvement or long-term dropout guarantee. Settings and rollback documented in diagnostics/audio-quality.md.

## Rollback
See diagnostics/audio-quality.md. Preserve pre-existing repository changes; commit only experiment artifacts created for this task.

## Blocked Handover
G3 and G4 resumed and passed after Pixel reconnection.
G5 passed with user listening feedback. All five gates met; retain the candidate without further tuning. Long-term stability and a controlled subjective comparison remain untested.
