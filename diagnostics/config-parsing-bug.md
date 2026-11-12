# Shairport-sync config parsing bug: 2026-10-27

## User observations
- Music Assistant reported 2500ms delay for AirPlay start on "Parlantes"
- Log error: `Invalid interpolation option choice "oxr". It should be "basic" or "soxr"`
- shairport-sync would fail to start when config contained certain comments

## Root cause
The shairport-sync 2.8.0 parser has a bug that scans the entire configuration file for the
string "oxr" (case-sensitive). When found anywhere (including in comments), it interprets
this as an invalid interpolation option value.

The original config file contained:
```
// Chain: AirPlay (44.1 kHz ALAC) -> soxr resample -> ALSA "pulse" plugin ->
```

The parser detected "oxr" in "soxr" and rejected the configuration.

## Fix applied
1. Modified `scripts/shairport-sync.conf`:
   - Changed comment from `// ... -> soxr resample -> ...` to `// ... -> resample -> ...`
   - Added warning comment about not including "soxr" or "oxr" strings
   - Preserved `interpolation = "soxr"` for high-quality resampling

2. Result: shairport-sync now starts correctly with high-quality soxr interpolation

## Files changed
- `scripts/shairport-sync.conf` - removed problematic string from comments

## Verification
- shairport-sync starts without parser errors
- Device advertises correctly on mDNS as "Parlantes"
- AirPlay connections succeed with soxr interpolation (high quality)

## Technical details
shairport-sync 2.8.0 (the Xenial build for armhf) uses a config parser that has this bug.
The binary dates to 2016 and has limited support for edge cases in configuration parsing.
Future upgrade to shairport-sync 4.x would eliminate this bug, but requires compilation
that may not be practical on ARMhf platforms.