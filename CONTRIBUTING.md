# Contributing

Small, focused changes are welcome. Open an issue with macOS version, reproduction steps and expected behavior. Do not share credentials, raw account responses or private session files.

Run `./script/check_pace.sh` and `./script/build_app.sh` before proposing changes. With full Xcode, also run `swift test`. UI changes should keep the collapsed bar and expanded card on the same cumulative-used coordinate system. Include screenshots using fictional data only.

The orange marker is the expected progress at the current time, computed from the service's reset time and window duration. Keep missing-window handling, reset boundary tests and upstream attribution intact. Add tests when changing pacing or quota parsing.
