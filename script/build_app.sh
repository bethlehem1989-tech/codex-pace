#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/Codex Pace.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Support/Info.plist)"
if [[ "${1:-}" == "--universal" ]]; then
  swift build -c release --arch arm64
  swift build -c release --arch x86_64
  mkdir -p "$APP/Contents/MacOS"
  lipo -create .build/arm64-apple-macosx/release/CodexUsageNano \
    .build/x86_64-apple-macosx/release/CodexUsageNano -output "$APP/Contents/MacOS/CodexUsageNano"
else
  swift build -c release
  BUILD_DIR="$(swift build -c release --show-bin-path)"
  mkdir -p "$APP/Contents/MacOS"
  cp "$BUILD_DIR/CodexUsageNano" "$APP/Contents/MacOS/CodexUsageNano"
fi
mkdir -p "$APP/Contents/Resources"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE"
chmod +x "$APP/Contents/MacOS/CodexUsageNano"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built Codex Pace %s: %s\n' "$VERSION" "$APP"
