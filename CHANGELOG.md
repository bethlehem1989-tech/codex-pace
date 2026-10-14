# Changelog

## 1.0.1 — 2026-10-14

- Simplify to a 64×16 tab with no visible text.
- Use WeChat green (#07C160) for cumulative usage and orange (#FF9500) for current expected pace.
- Reduce hover details to two numbers: used and expected now.
- Constrain bar fill height so it stays within the track.

## 1.0.0 — 2026-10-14

- Rename the distribution to Codex Pace; retain MIT upstream attribution.
- Use a cumulative-used bar in both collapsed and expanded views.
- Add an orange daily target marker and a visible `今 xx%` target label to the small tab.
- Show quota remaining, actual usage, current linear pace, tonight's cumulative goal and reset time on hover.
- Support weekly-only accounts, avoid invented targets for missing/expired windows, and label stale readings.
- Package a macOS 14+ universal app, installer, checksum, and source-backed tests.
