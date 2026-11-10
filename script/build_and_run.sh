#!/usr/bin/env bash
set -euo pipefail
if test -d /Applications/Xcode.app/Contents/Developer; then export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"; fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
BUILD_CONFIGURATION="${VAPULA_BUILD_CONFIGURATION:-debug}"
APP_BUNDLE="$ROOT_DIR/dist/VAPULA.app"
if pgrep -x VAPULA >/dev/null; then
  echo "Cierra VAPULA antes de recompilar para conservar cualquier operación activa." >&2
  exit 1
fi
if test "$MODE" = "--stage-built"; then
  # zsh/bash on macOS does not guarantee case-conversion parameter expansion.
  if test "$BUILD_CONFIGURATION" = "release"; then BUILD_DIR="$ROOT_DIR/.build/out/Products/Release"; else BUILD_DIR="$ROOT_DIR/.build/out/Products/Debug"; fi
  test -x "$BUILD_DIR/VAPULA" || { echo "No hay ejecutable verificado. Ejecuta primero script/test.sh -c $BUILD_CONFIGURATION." >&2; exit 1; }
else
  swift build -c "$BUILD_CONFIGURATION" -j "${VAPULA_BUILD_JOBS:-2}"
  BUILD_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
fi
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"
cp "$BUILD_DIR/VAPULA" "$APP_BUNDLE/Contents/MacOS/VAPULA"
cmp "$BUILD_DIR/VAPULA" "$APP_BUNDLE/Contents/MacOS/VAPULA"
for resource in "$BUILD_DIR"/VAPULA_VapulaApp.bundle "$BUILD_DIR"/VAPULA_VapulaCore.bundle; do
  if test -d "$resource"; then cp -R "$resource" "$APP_BUNDLE/Contents/Resources/"; for locale in "$resource"/*.lproj; do if test -d "$locale"; then cp -R "$locale" "$APP_BUNDLE/Contents/Resources/"; fi; done; fi
done
if test -f "$BUILD_DIR/libDuckDB.dylib"; then
  cp "$BUILD_DIR/libDuckDB.dylib" "$APP_BUNDLE/Contents/Frameworks/"
  install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/VAPULA"
  codesign --force --sign - "$APP_BUNDLE/Contents/Frameworks/libDuckDB.dylib"
fi
cp "$ROOT_DIR/Resources/Brand/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/"
if test -d "$ROOT_DIR/Resources/Licenses"; then cp -R "$ROOT_DIR/Resources/Licenses" "$APP_BUNDLE/Contents/Resources/"; fi
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>es</string><key>CFBundleLocalizations</key><array><string>es</string><string>en</string></array>
<key>CFBundleName</key><string>VAPULA</string><key>CFBundleExecutable</key><string>VAPULA</string>
<key>CFBundleIdentifier</key><string>cl.sebastianpasten.VAPULA</string><key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.4</string><key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleIconFile</key><string>AppIcon</string><key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>VAPULA Project</string><key>CFBundleTypeRole</key><string>Editor</string><key>LSItemContentTypes</key><array><string>cl.sebastianpasten.vapula-project</string></array></dict></array>
<key>UTExportedTypeDeclarations</key><array><dict><key>UTTypeIdentifier</key><string>cl.sebastianpasten.vapula-project</string><key>UTTypeDescription</key><string>VAPULA Project</string><key>UTTypeConformsTo</key><array><string>com.apple.package</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>vapula</string></array></dict></dict></array>
</dict></plist>
PLIST
# Finder/iCloud may attach Finder metadata to a generated Desktop bundle.
# Only clear these nonessential attributes inside this freshly generated app.
xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE"
case "$MODE" in
  --build-only|--stage-built) ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --verify|verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 2; pgrep -x VAPULA >/dev/null ;;
  --logs|logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "VAPULA"' ;;
  --telemetry|telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "cl.sebastianpasten.VAPULA"' ;;
  --debug|debug) lldb -- "$APP_BUNDLE/Contents/MacOS/VAPULA" ;;
  *) echo "usage: $0 [run|--build-only|--stage-built|--verify|--logs|--telemetry|--debug]" >&2; exit 2 ;;
esac
