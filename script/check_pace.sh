#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PACE_CHECK_BINARY="$(mktemp -t codex-pace-check)"
trap 'rm -f "$PACE_CHECK_BINARY"' EXIT
swiftc Sources/CodexUsageNano/Models/UsageSnapshot.swift \
  Sources/CodexUsageNano/Models/UsagePace.swift \
  Sources/CodexUsageNano/Services/CodexUsageService.swift \
  Tests/Standalone/PaceChecks.swift -o "$PACE_CHECK_BINARY"
"$PACE_CHECK_BINARY" "$@"
