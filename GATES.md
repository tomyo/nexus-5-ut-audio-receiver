# Gates: Bluetooth jack audio quality experiment

Scope: Diagnose codec and playback headroom, test one reversible quality improvement, and retain only a stable candidate. No guarantee of zero dropouts beyond the measured window.

- [x] G1: Save working phone configuration and exact rollback steps before changing audio.
  EVIDENCE: Saved /home/phablet/audio-quality-backup/daemon.conf; diagnostics/audio-quality.md documents restore and restart commands.
- [x] G2: Record live Bluetooth codec evidence, sample rates, jack routing, CPU baseline, and available dropout diagnostics; distinguish unavailable evidence from confirmed facts.
  EVIDENCE: BlueZ SBC configuration 21 15 02 35; 44.1 kHz input, 48 kHz jack; baseline 6.87% one-core CPU over 30.01 seconds; actual bitrate and reliable underrun counters unavailable. See diagnostics/audio-quality.md.
- [ ] G3: Test one resampler quality step with a verified active setting and correct jack routing, or restore baseline if unsafe.
  EVIDENCE: pending
- [ ] G4: Compare CPU over equal playback windows and monitor stability for at least three minutes; record limits of dropout detection.
  EVIDENCE: pending
- [ ] G5: Obtain listening feedback before calling the candidate better, and document retained settings and rollback.
  EVIDENCE: pending

## Rollback
See diagnostics/audio-quality.md. Preserve pre-existing repository changes; commit only experiment artifacts created for this task.

## Blocked Handover
ABANDON: G3 Blocked pending Pixel reconnect/resume: PulseAudio restart restored the jack sink but removed the Bluetooth source; candidate speex-fixed-4 is configured, not yet verified on a live stream.
ABANDON: G4 Cannot measure candidate playback CPU or stability until Bluetooth music resumes.
ABANDON: G5 Requires user listening feedback after playback resumes. These gates remain open for the next pass; no improvement claimed.
