# Volume-only recovery

Replaced the faulty vol_sync.py automation with a one-way volume mapper after user approval. It reads BlueZ objects through installed python3-dbus, chooses a single active incoming A2DP transport (local UUID 0000110b), and applies changed Volume values to sink.primary. No device MAC or controller path is hardcoded. Multiple simultaneous incoming senders are intentionally left alone because the shared output has no unique owner.

The script does not modify profiles, create/unload bridges, change Bluetooth volume, or alter D-Bus permissions. This supersedes the earlier bridge-management and bidirectional-volume claims. The prior script is backed up on phone at /home/phablet/audio-quality-backup/vol_sync.before-volume-only.py; it is known faulty and should not be restarted as a routine rollback.

Three unit tests cover changed/unchanged volume, idle/absent/invalid/ambiguous transports, zero/max volume, and reconnect. Live deployment restarted only vol-sync: Bluetooth volume 76 mapped to output 59%; source remained RUNNING and policy loopback module 28 remained unchanged. User still needs to press Pixel volume keys and confirm audible adjustment. Pause/resume, reboot, and other senders have not been live-tested in this recovery. Explicit 200 ms buffering is not active on the current policy bridge.
