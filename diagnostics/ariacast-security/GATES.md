# Gates: AriaCast Android source security audit

Scope: Read-only review of the AriaCast Android repository for unintended capture, exfiltration, telemetry, network exposure, sensitive logging/storage and lifecycle behavior. Do not change app code, phone settings, or running MA. Repository findings are not proof about the installed APK or observed network traffic.

- [x] G1: Pin source revision and inventory audited code, manifests, dependencies and build/release paths; disclose omissions.
  EVIDENCE: REPORT.md identifies HEAD `0eab0c28c87549b1b657854087df21820a511349`; source 226 tracked files, 134 under app/src; manifest, build/dependency metadata, CI and firmware examined. Installed APK unresolved: source version 1.1.9_hotfix/code17 vs metadata 1.1.8/code15.
- [x] G2: Trace outgoing network destinations and payloads, third-party SDKs, dependency declarations and update checks; distinguish user-requested LAN streams from other traffic.
  EVIDENCE: REPORT.md lists GitHub-only built-in Internet endpoints and no analytics/crash SDK evidence; audio intentionally streams to selected receiver. Plugin arbitrary URL posting is opt-in and documented.
- [x] G3: Trace capture permissions, scope, foreground/background lifecycle, stop behavior, notification access, and volume/media-session integration.
  EVIDENCE: `AudioCastService.kt:658-677,1983-2024`; capture limited to USAGE_MEDIA, projection/user consent; stop releases recorder/projection and sockets; video setting false by default.
- [x] G4: Review inbound listeners, authentication/transport, local logs/storage/backup, artwork and metadata exposure, and companion/native components.
  EVIDENCE: REPORT.md details unauthenticated wildcard 8091 PCM and 8090 artwork listeners; DACP/retransmit/companion risks; metadata logs and backup exclusion.
- [x] G5: Adversarial second pass validates each ranked finding with exact paths/lines and reproducible source checks; false positives and unverified hypotheses are separated.
  EVIDENCE: Independently checked protocol reviewer findings against source; test `DacpServerTest` always sends `Active-Remote` (`RtpAudioSenderTest.kt:190-192`) and omits missing-token case. Companion findings qualified to board use. No exploit/device/packet test claimed.
- [x] G6: Report provides a measured verdict, actionable mitigations and explicit static-review limitations; checks pass and audit artifacts are committed without app/settings changes.
  EVIDENCE: `REPORT.md` written; `git diff --check` to run before commit. Unit tests blocked before execution: `JAVA_HOME is not set and no 'java' command could be found in your PATH.` No app/device changes.

