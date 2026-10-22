# Optional Ubuntu Touch Lockscreen Removal

A dedicated receiver may not need a lockscreen, but disabling it reduces physical security. Keeping the PIN is the safest default and does not prevent Bluetooth playback.

Removing the phablet user's PIN can affect password-based sudo and SSH authentication. Do not remove it until you have independently verified another administrator login and sudo access on your installed Ubuntu Touch version.

## Prepare Administrator Access

Setup step 6 creates a rescueadmin account and adds it to the sudo group. The new account is locked: setup does not install a default password or SSH key. If the account already exists, setup leaves it unchanged.

While the phablet PIN and sudo still work, open a terminal on the phone and run:

```bash
sudo passwd rescueadmin
```

Choose a strong, unique password. If password assignment fails because of the phone's authentication configuration, stop and keep the PIN; do not inject a shared password hash as a workaround.

Before changing the lockscreen, verify a separate login as rescueadmin and verify that it can run sudo. For example, if SSH is enabled and password login is permitted:

```bash
ssh rescueadmin@<phone-IP>
sudo -v
sudo id -u
```

The last command must print 0. Do not close your existing administrator session until the separate login succeeds. Group membership alone does not prove sudo works on this device.

## Optional PIN Removal

Only after those checks, use System Settings > Security & Privacy to change the passcode/PIN to None, if supported by your installed version. Verify administrator access again afterward. Keep the PIN if any check fails or the behavior differs from these instructions.

Anyone with physical access can then use the unlocked phone. This change is optional and is not required for the audio receiver setup.

## SSH And Audio Administration

SSH availability, permitted authentication methods, and account keys are separate configuration steps; see diagnostics/ssh-access.md. Existing phablet key authentication may still work without a PIN. Use the actual phone IP unless mDNS has been verified; a .local hostname is not guaranteed.

From a verified rescueadmin session, you can switch to the audio user's login environment with:

```bash
sudo -iu phablet
```

PulseAudio commands may additionally need PULSE_RUNTIME_PATH set to the configured /run/user/<PA_UID>/pulse directory. Wi-Fi is intentionally disabled during Bluetooth streaming, so prefer USB ADB for live audio inspection.
