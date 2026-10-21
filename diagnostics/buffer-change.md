> Historical experiment, superseded by the volume-only recovery. Do not restore the old profile/bridge automation. Current contract: README.md and diagnostics/stable-cleanup.md. Explicit 200 ms buffering and Nexus-to-Pixel volume sync are not active.

# Music loopback buffer: 2026-10-21

User approved a reversible 200 ms Bluetooth loopback target for music, accepting extra delay. Updated scripts/vol_sync.py and deployed to /home/phablet/vol_sync.py. Restarted only vol-sync, not PulseAudio or the phone. speex-fixed-4 and sample rates unchanged.

The service now replaces a policy-created bridge for the active Bluetooth source if it lacks latency_msec=200; otherwise it leaves the buffered bridge alone. This matters because module-bluetooth-policy normally creates a bridge on connection before our watchdog runs. Other sources' loopbacks are not modified.

Verification: Python AST compile and mocked subprocess checks passed for absent bridge, policy-created default bridge, and already-buffered bridge (no repeated reload). Service restarted successfully. No Bluetooth source/loopback was present at deployment because playback had stopped: actual latency and audible stability are NOT yet verified. Resume Bluetooth music and check `pactl list short modules` for latency_msec=200 before calling this successful. Target latency is not a guaranteed achieved delay or cure for chopping. Existing PulseAudio default loopback latency was not measured; do not assume 200 ms necessarily increases every previous bridge's effective latency.

Rollback: restore /home/phablet/audio-quality-backup/vol_sync.before-buffer.py to /home/phablet/vol_sync.py, restart the root Upstart vol-sync service, and reconnect Bluetooth to recreate the prior bridge. Reverting the file alone does not replace an already-running 200 ms bridge. Repository rollback should target this change only, preserving other work.
