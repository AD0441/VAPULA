#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if test "${VAPULA_RELEASE_REVIEWED:-0}" != 1; then
  echo "Release bloqueada: completa la revisión visual/funcional y documenta VALIDATION.md. Usa VAPULA_RELEASE_REVIEWED=1 solo después de esa revisión." >&2
  exit 1
fi
VAPULA_BUILD_CONFIGURATION=release ./script/build_and_run.sh --build-only
codesign --verify --deep --strict dist/VAPULA.app
if otool -L dist/VAPULA.app/Contents/MacOS/VAPULA | rg '/opt/homebrew|/usr/local|/private/tmp|\.build/'; then
  echo "Dependencia de desarrollo detectada; no se publica." >&2
  exit 1
fi
COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent dist/VAPULA.app dist/VAPULA-0.1.0-macos-arm64.zip
(cd dist && shasum -a 256 VAPULA-0.1.0-macos-arm64.zip > SHA256SUMS.txt && shasum -a 256 -c SHA256SUMS.txt)
echo "ZIP verificado. No se publica automáticamente."
