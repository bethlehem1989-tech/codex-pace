#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./script/build_app.sh
open "dist/Codex Pace.app"
