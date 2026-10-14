#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./script/build_app.sh --universal
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Support/Info.plist)"
STAGE="dist/Codex-Pace-${VERSION}-macOS-universal"
mkdir -p "$STAGE"
ditto "dist/Codex Pace.app" "$STAGE/Codex Pace.app"
cp distribution/Install.command "$STAGE/Install.command"
cp distribution/使用说明.txt "$STAGE/使用说明.txt"
cp LICENSE "$STAGE/LICENSE"
cp THIRD_PARTY_NOTICES.md "$STAGE/THIRD_PARTY_NOTICES.md"
chmod +x "$STAGE/Install.command"
ARCHIVE="Codex-Pace-${VERSION}-macOS-universal.zip"
ditto -c -k --keepParent "$STAGE" "dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
printf 'Packaged: dist/%s\n' "$ARCHIVE"
