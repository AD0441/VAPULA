#!/usr/bin/env bash
set -euo pipefail
if test -d /Applications/Xcode.app/Contents/Developer; then export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"; fi
cd "$(dirname "${BASH_SOURCE[0]}")/.."
swift test -j "${VAPULA_BUILD_JOBS:-2}" "$@"
