# Wi-Fi SSH access: restored 2026-10-21

## Verified access

```sh
ssh phablet@192.168.11.197
```

Public-key authentication from this workstation succeeded and returned hostname `parlantes`. The workstation's existing Ed25519 public key was added to `/home/phablet/.ssh/authorized_keys`, with directory mode 700 and file mode 600. No private key was copied and password authentication was not enabled.

## Why the previous setup was not persistent

`setup.sh` already has an SSH setup section: it generates host keys, edits password authentication settings in `/etc/ssh/sshd_config`, and restarts SSH. However, it does not enable Ubuntu Touch's persistent SSH property.

The installed `/etc/init/ssh.override` contains `manual` and overrides the command with `sshd -D -o PasswordAuthentication=no`. Therefore the normal runlevel startup and the installer's password-authentication edits are not sufficient. `/etc/init/ssh-property-watcher.conf` starts/stops SSH using `persist.service.ssh` on Android container startup/property events. The property was initially empty.

## Applied fix

Using root privileges through USB, set:

```sh
setprop persist.service.ssh true
```

The property watcher started SSH automatically. A subsequent explicit `initctl start ssh` reported it already running. Verified `getprop persist.service.ssh` returns `true`, and an actual key-authenticated SSH session over Wi-Fi succeeds.

No root filesystem edits or remounts were needed. This uses the platform's persistent boot mechanism, but a reboot test was deliberately not performed to avoid interrupting playback. The existing installer has NOT been changed; its unrelated local edits were preserved. A future installer fix should set this property and provision public-key access rather than enable password login.

## Limits and rollback

- The Bluetooth playback Wi-Fi sync service still turns Wi-Fi OFF during streaming. SSH cannot be reached while the radio is off; stop/disconnect playback and enable Wi-Fi, or use USB ADB. Enabling SSH does not override the radio policy.
- The address uses DHCP and may change. mDNS remains disabled, so `parlantes.local` is not currently available.
- To disable SSH persistently, run `sudo setprop persist.service.ssh false` on the phone (or through USB). The watcher should stop SSH. If using SSH for this command, expect the connection to close.
- To revoke this workstation only, remove its public-key entry from `~/.ssh/authorized_keys`; preserve other authorized keys.
- SSH listens on network interfaces, not exclusively Wi-Fi. Restrict access at the router/firewall if needed; avoid exposing port 22 to the Internet.
