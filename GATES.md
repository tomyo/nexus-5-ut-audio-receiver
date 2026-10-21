# Gates: Stable receiver cleanup

Scope: Preserve working volume-only Bluetooth receiver, align installer and documentation, retain supporting features, defer buffer tuning unless chopping returns. Preserve pre-existing local edits.

- [x] G1: Volume mapper tests cover safe routing isolation and sender lifecycle.
  CHECK: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests
  EXPECT: OK
  EVIDENCE: Ran 12 tests in 0.003s | OK
- [x] G2: Installer and service configuration have executable regression checks and syntax validation.
  CHECK: bash -n setup.sh scripts/adjust-screen-timeout.sh && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_setup.py
  EXPECT: OK
  EVIDENCE: Ran 4 tests in 0.002s | OK
- [x] G3: Supporting scripts reviewed; unsupported claims superseded; no explicit buffer enforced.
  EVIDENCE: Full helper/template review and changes recorded in diagnostics/stable-cleanup.md. README and historical diagnostic notices distinguish current behavior; tests reject routing commands and latency_msec in the volume service.
- [ ] G4: Live deployed script matches repository and routing survives volume service restart and pause/resume/reconnect.
  EVIDENCE: Four deployed script hashes matched; three helper restarts succeeded. No active Bluetooth source existed then; later ADB returned no devices/emulators found. Playback lifecycle checks could not be completed.
ABANDON: G4 Live pause/resume/reconnect verification blocked by unavailable phone; exact follow-up is in diagnostics/stable-cleanup.md.
- [x] G5: Reboot behavior verified or explicitly handed over if disruptive/unavailable; final diff clean and committed without unrelated changes.
  EVIDENCE: Reboot verification explicitly handed over in diagnostics/stable-cleanup.md because phone unavailable. Cleanup tracked in git; unrelated screen-timeout edit and untracked lockscreen/power test files excluded. Final diff whitespace validation passed.
