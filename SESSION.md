# Project State: Nexus 5 Bluetooth Audio Receiver

## Objective
Convert a Nexus 5 (hammerhead) into a dedicated, high-quality Bluetooth audio receiver for a stereo system.

## Current Configuration
- **Operating System:** Ubuntu Touch (Linux-based, installed via UBports).
- **Partition Layout:** Reset to Stock 16GB (Fixed "No space left on device" errors in installer).
- **Audio Stack:** PulseAudio 8.0.
- **Bluetooth Stack:** BlueZ 5.41.
- **System Modifications:**
    - `/etc/bluetooth/main.conf`: Enabled `Source,Sink,Media,Socket`. Set `Name=Parlantes` and `Class=0x200414` (Loudspeaker).
    - `/etc/pulse/daemon.conf`: Set `resample-method=trivial`, `default-sample-rate=44100`, and increased fragments to `10` x `50ms` for stability. Enabled `realtime-scheduling`.
    - `/etc/init/vol-sync.conf`: Custom persistent Upstart service that manages:
        - CPU Governor (set to `performance`).
        - WiFi Radio (disabled to prevent 2.4GHz interference).
        - PulseAudio environment permissions.
        - Execution of `vol_sync.py` and `bt_agent.py`.

## Current Status
- **Identity:** Device recognized as a "Wireless Speaker" named **Parlantes**.
- **Audio Quality:** Good. WiFi is disabled to prevent interference. PulseAudio is tuned for `trivial` resampling.
- **Auto-Routing:** Functional. Script switches between `[Out] Headphones` and `[Out] Speaker`.
- **Auto-Pairing:** Background agent automatically accepts and trusts new pairing requests.
- **Volume Sync:** Intermittent. Works after specific permission fixes but may drop after reconnection or reboot if PulseAudio environment variables aren't strictly maintained.

## Technical Journey Summary
1.  **LineageOS 20 (Android 13):** Failed. Modern Android Bluetooth/Audio HAL too restrictive.
2.  **LineageOS 15.0 (Android 8.0):** Failed. Buggy setup.
3.  **Android 6.0.1 (Stock):** Partially successful. Required complex manual patching.
4.  **Ubuntu Touch:** **Winner.** Full Linux control allows direct manipulation of PulseAudio and BlueZ.

## Next Steps
1. Troubleshoot the Volume Sync instability (ensure `PULSE_RUNTIME_PATH` and permissions are persistent).
2. Monitor for any reconnection edge cases.
3. Refine the BlueZ agent for better security/reliability.
